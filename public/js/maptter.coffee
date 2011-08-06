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
  refreshLockCount: 0

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
    $("<li>").addClass("status")
      .append($("<div>").addClass("image").append($("<img>").attr(src: tweet.user.profile_image_url)))
      .append($("<div>").addClass("content")
        .append($("<span>").text(tweet.user.screen_name).addClass("screenname"))
        .append($("<span>").text(tweet.user.name).addClass("name"))
        .append($("<div>").text(tweet.text).addClass("text"))
        .append($("<div>").addClass("tool")
          .append($("<a>").addClass("timestamp").attr(
              href: "http://twitter.com/#!/" + tweet.user.screen_name + "/status/" + tweet.id_str
              target: "_blank"
              title: new Date(tweet.created_at)
            ).timeago()
          )
          .append($("<a>").attr(href: "#").text("reply").addClass("reply").click(->
            $("#tweetPostForm input[name=in_reply_to_status_id]").val(tweet.id_str)
            $("#tweetPostForm textarea[name=tweet]").val("@" + tweet.user.screen_name + " ")
            return false
          ))
          .append(@makeFavoriteElement(tweet))
        ))
      .append($("<div>").addClass("clear"))
      .hover((-> $(this).find("div.tool").css(visibility: "visible")), (-> $(this).find("div.tool").css(visibility: "hidden")))

  makeFavoriteElement: (tweet) ->
    fav = $("<a>").attr(href: "#").text("favorite").addClass("favorite")
    fav.addClass("favorited") if tweet.favorited
    fav.click(->
      api = if $(this).hasClass("favorited") then "delete" else "create"
      $.post "/twitter/favorite/" + api, tweet_id: tweet.id_str, (response, status)->
        if api == "create"
          fav.addClass("favorited")
        else
          fav.removeClass("favorited")
        return false
    )
    return fav

  getTimeline: ->
    return if $(".ui-draggable-dragging").length > 0
    return if @refreshLockCount > 0
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
      @updateNeighborsTimeline diffTimeline, true
      diffTimeline.reverse()
      for tweet in diffTimeline
        $("div#timelineTab .statusList").prepend(@makeTweet tweet)
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
          title: user.screen_name
        )
        .hover((->
            $("#map").addClass("addFriend")
            $("#map strong").show()
           ),(->
            $("#map strong").hide()
            $("#map").removeClass "addFriend")
        )
      )

router({
  path: "/"
  func: ->
    $(document).ready ->
      window.maptter.initFriendsMap()

      $("div#friendsScrollContainer").hide()
      $("#addFriendButton").click ->
        $("div#friendsScrollContainer").slideToggle("slow")

      $("#timelineTabs").tabs()

      $("#map").droppable
        accept: ":not(.icon)"
        drop: (event, ui) ->
          window.maptter.refreshLockCount++
          ui.helper.draggable(disabled: true).attr(src: "img/loading.gif")
          friend = ui.helper.data("profile")
          mapOffset = $("#map").offset()
          $.ajax {
            url: "/map/add"
            type: "POST"
            data:
              user_id: friend.id_str
              top: ui.offset.top - mapOffset.top
              left: ui.offset.left - mapOffset.left
              profile: friend
            error: (request, status, error) ->
              window.maptter.refreshLockCount--
              ui.helper.remove()
            success: (data, status) ->
              window.maptter.refreshLockCount--
              $.extend(friend, data)
              icon = window.maptter.makeDraggableIcon(friend).hide()
              window.maptter.friends.push icon
              $("#map").append icon
              ui.helper.remove()
              icon.fadeIn 'slow'
              window.maptter.updateNeighbors()
          }

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

      $("#tweetPostForm").submit ->
        $.post "/twitter/update", $("#tweetPostForm").serialize(), (tweet, status) ->
          $("#tweetPostForm textarea[name=tweet]").val ""
          tweetElem = window.maptter.makeTweet(tweet).addClass("tmp")
          $("div#timelineTab .statusList").prepend(tweetElem.clone())
          $("div#mapTab .statusList").prepend(tweetElem)
        return false

    $(window).unload ->
      window.maptter.saveMoveTasks()
})
