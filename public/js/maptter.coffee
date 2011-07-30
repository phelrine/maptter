square = (x) -> x * x
router = (args...) ->
  pathname = location.pathname
  for route in args
    path = route.path
    func = route.func
    return unless path and func
    return func() if path == pathname or (path.test and path.test pathname)

window.maptter ?=
  friends: []
  moveTasks: {}
  neighborIDs: []
  neighborLength: 200
  allTimeline: []
  neighborsTimeline: []

  initFriendsMap: ->
    setInterval (=> @saveMoveTasks()), 10000
    setInterval (=> @getTimeline()), 20000

    $.get "/map/friends", "", (friends, status) =>
      @friends = for friend in friends
        icon = @makeDraggableIcon friend
        $("#map").append icon
        icon
      @updateNeighbors()

    @getTimeline()

  makeDraggableIcon: (friend) ->
    return $("<img>").addClass("icon").data(
        friend_id: friend.friend_id
        user_id: friend.user_id
      ).attr(
        src: friend.profile_image_url
        alt: friend.screen_name
        title: friend.screen_name
      ).css(
        top: friend.top
        left: friend.left
      ).draggable(
        stack: ".icon"
        containment: "parent"
        stop: (event, ui) =>
          user_id = ui.helper.data("user_id")
          @moveTasks[user_id] =
            friend_id: ui.helper.data("friend_id")
            top: ui.position.top
            left: ui.position.left
          @updateNeighbors()
      )

  saveMoveTasks: ->
    return if $(".ui-draggable-dragging").length > 0 or $.isEmptyObject @moveTasks
    params = JSON.stringify(for id, value of @moveTasks
        value
    )
    $.post "/map/move", tasks: params, =>
        @moveTasks = {}
    return

  updateNeighbors: ->
    user = @friends[0]
    @neighborIDs = []

    for friend in @friends
      squaredTop = square(parseFloat(user.css "top") - parseFloat(friend.css "top"))
      squaredLeft = square(parseFloat(user.css "left") - parseFloat(friend.css "left"))
      length = Math.sqrt(squaredTop + squaredLeft)
      if length < @neighborLength
        @neighborIDs.push friend.data "user_id"
        friend.css "opacity", 1
      else
        friend.css "opacity", 0.5

    @updateNeighborsTimeline(@allTimeline)

  updateNeighborsTimeline: (timeline, merge = false)->
    neighborsTimeline = []

    for tweet in timeline
      for neighbor in @neighborIDs
        neighborsTimeline.push tweet if neighbor == tweet.user.id_str

    if merge == true
      diff = []
      $.merge diff, neighborsTimeline
      @neighborsTimeline = $.merge neighborsTimeline, @neighborsTimeline
      diff.reverse()
      for tweet in diff
        $("div#mapTab .statusList").prepend(@makeTweet tweet)
    else
      @neighborsTimeline = neighborsTimeline
      $("div#mapTab .statusList").empty()
      for tweet in neighborsTimeline
        $("div#mapTab .statusList").append(@makeTweet tweet)

  makeTweet: (tweet) ->
    $("<div>").addClass("status").append($("<img>").attr(src: tweet.user.profile_image_url).addClass("image"))
      .append($("<div>").text(tweet.user.screen_name).addClass("screenname"))
      .append($("<div>").text(tweet.user.name).addClass("name"))
      .append($("<div>").text(tweet.text).addClass("text"))
      .append($("<a>").attr(href: "#").text("reply").addClass("reply").click((->
      		$("#tweet-post-form input[name=in_reply_to_status_id]").val(tweet.id_str)
      		$("#tweet-post-form textarea[name=tweet]").val("@" + tweet.user.screen_name + " ");
      )))
      .append($("<div>").text("RT").addClass("RT"))
      .append($("<div>").css(clear: "both"))

  getTimeline: ->
    return if $(".ui-draggable-dragging").length > 0
    params = count: 100
    diffTimeline = []

    unless(@allTimeline.length == 0)
      params.since = @allTimeline[0].created_at
      params.count = 40

    $.get "twitter/timeline", params, (timeline, status)=>
      @updateActiveUser(timeline)
      if @allTimeline.length == 0
        diffTimeline = timeline
      else
        latestID = parseInt(@allTimeline[0].id_str, 10)
        for tweet in timeline
          diffTimeline.push tweet if latestID < parseInt(tweet.id_str, 10)

      $(".tmp").remove() if diffTimeline.length > 0
      latestTimeline = []
      $.merge latestTimeline, diffTimeline
      @allTimeline = $.merge latestTimeline, @allTimeline
      for tweet in diffTimeline
        $("div#tlTab .statusList").append(@makeTweet tweet)

      @updateNeighborsTimeline diffTimeline, true
    false

  updateActiveUser: (timeline = @allTimeline)->
    users = {}

    for tweet in timeline
      users[tweet.user.id_str] = tweet.user

    for friend in @friends
      delete users[friend.data("user_id")]

    $("#friendsList").empty()
    for id, user of users
      $("#friendsList").append(
        $("<img>").draggable(
          revert: "invalid"
          opacity: 0.5
        )
        .data({profile: user})
        .attr(
          src: user.profile_image_url
          alt: user.screen_name
          alt: user.screen_name
        )
        .css(
          height: "48px"
          width: "48px"
        )
      )

router({
  path: "/"
  func: ->
    $(document).ready ->
      window.maptter.initFriendsMap()

      $("#friendsScrollContainer").hide()
      $("#addFriendsBtn").click ->
        $("#friendsScrollContainer").toggle("slow")

      $("#tlPanel").tabs().draggable
        containment: "parent"
        stack: ".panel"

      $("#map").droppable
        accept: ":not(.icon, .panel)"
        drop: (event, ui) ->
          ui.helper.draggable(disabled: true).attr(src: "img/loading.gif")
          friend = ui.helper.data("profile")
          mapOffset = $("#map").offset()
          $.post "/map/add", {
              user_id: friend.id_str,
        			top: ui.offset.top - mapOffset.top,
        			left: ui.offset.left - mapOffset.left,
        			profile: friend
            }, (data, status) ->
              $.extend(friend, data)
              icon = window.maptter.makeDraggableIcon(friend).hide()
              window.maptter.friends.push icon
              $("#map").append icon
              ui.helper.remove()
              icon.fadeIn 'slow'
              window.maptter.updateNeighbors()

      $(".slider").slider
        range: "min"
        min: 100
        max: 600
        value: window.maptter.neighborLength
        slide: (event, ui) ->
          $("#slider-length-display").text "Length: " + ui.value
        stop: (event, ui) ->
          window.maptter.neighborLength = ui.value
          window.maptter.updateNeighbors()

      $("#tweet-post-form").submit ->
        $.post "/twitter/update", $("#tweet-post-form").serialize(), (tweet, status) ->
          $("#tweet-post-form textarea[name=tweet]").val ""
          $(".timeline").prepend(maptter.makeTweet(tweet).addClass("tmp"))
        return false

    $(window).unload ->
      window.maptter.saveMoveTasks()
})
