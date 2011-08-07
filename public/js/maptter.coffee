square = (x) -> x * x
router = (args...) ->
  pathname = location.pathname
  for route in args
    path = route.path
    func = route.func
    return unless path and func
    return func() if path == pathname or (path.test and path.test pathname)

window.maptter ?=
  user: null
  friends: {}
  saveTasks: {}
  distances: {}
  neighborLength: 200
  allTimeline: []
  mapTimeline: []
  refreshLockCount: 0

  initFriendsMap: ->
    setInterval (=> @saveMap()), 10000
    setInterval (=> @getTimeline()), 20000

    $.get "/map/friends", "", (friends, status) =>
      for friend in friends
        icon = @makeDraggableIcon friend
        $("#map").append icon
        @friends[friend.friend_id] = icon
        @user = icon if @user == null
      @updateDistances()
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
        start: (event, ui) =>
          $(".qtip").qtip('hide')
        stop: (event, ui) =>
          friend_id = ui.helper.data("friend_id")
          @saveTasks[friend_id] =
            friend_id: ui.helper.data("friend_id")
            type: "move"
            top: ui.position.top
            left: ui.position.left
          @updateDistances()
      ).qtip(
        content:
          text: (api) ->
            return $("<p>").text(friend.name + " ")
              .append($("<a>").text("@" + friend.screen_name).attr(
                href: "http://twitter.com/#!/"+friend.screen_name
                target: "_blank"
              ))
              .after($("<a>").text("アイコンを削除").attr(href: "#").click(=>
                window.maptter.saveTasks[friend.friend_id] =
                  type: "remove"
                  friend_id: friend.friend_id
                $(".qtip").qtip('hide')
                $(this).hide('slow')
                $(this).empty()
              ))
        style:
          classes: "ui-tooltip-shadow"
        show:
          solo: true
          event: "click"
        hide:
          event: "click unfocus"
        position:
          my: "bottom left"
          at: "top left"
      )

  saveMap: ->
    return if $(".ui-draggable-dragging").length > 0 or $.isEmptyObject @saveTasks
    params = JSON.stringify(for id, value of @saveTasks
        value
    )
    @saveTasks = {}
    $.post "/map/save", tasks: params
    return

  updateDistances: ->
    @distances = {}
    for id, friend of @friends
      user_id = friend.data "user_id"
      squaredTop = square(parseFloat(@user.css "top") - parseFloat(friend.css "top"))
      squaredLeft = square(parseFloat(@user.css "left") - parseFloat(friend.css "left"))
      length = Math.sqrt(squaredTop + squaredLeft)
      @distances[user_id] ?= length
      @distances[user_id] = length if length < @distances[user_id]
      friend.css "opacity", if @distances[user_id] < @neighborLength then 1 else 0.5
    @updateMapTimeline(@allTimeline)

  updateMapTimeline: (timeline, merge = false)->
    recentMapTimeline = for tweet in timeline
      continue unless @distances[tweet.user.id_str]?
      tweet

    if merge == true
      diff = []
      $.merge diff, recentMapTimeline
      @mapTimeline = $.merge recentMapTimeline, @mapTimeline
      diff.reverse()
      for tweet in diff
        $("div#mapTab .statusList").prepend(@makeTweet tweet)
    else
      @mapTimeline = recentMapTimeline
      $("div#mapTab .statusList").empty()
      for tweet in @mapTimeline
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
    params = count: 80
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
      @updateMapTimeline diffTimeline, true
      diffTimeline.reverse()
      for tweet in diffTimeline
        $("div#timelineTab .statusList").prepend(@makeTweet tweet)
    false

  updateActiveUser: (timeline = @allTimeline)->
    users = {}

    for tweet in timeline
      users[tweet.user.id_str] = tweet.user

    for id, friend of @friends
      delete users[friend.data("user_id")]

    $("#friendsList").empty()
    for id, user of users
      $("#friendsList").append(
        $("<img>").draggable(
          revert: "invalid"
          opacity: 0.5
        )
        .data(profile: user)
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

      $("#addFriendButton").click ->
        $("#friendsList").slideToggle("slow")

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
              $("#map").append icon
              window.maptter.friends[data.frirnd_id] = icon
              ui.helper.remove()
              icon.fadeIn 'slow'
              window.maptter.updateDistances()
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
          window.maptter.updateDistances()

      $("#tweetPostForm").submit ->
        $.post "/twitter/update", $("#tweetPostForm").serialize(), (tweet, status) ->
          $("#tweetPostForm textarea[name=tweet]").val ""
          tweetElem = window.maptter.makeTweet(tweet).addClass("tmp")
          $("div#timelineTab .statusList").prepend(tweetElem.clone())
          $("div#mapTab .statusList").prepend(tweetElem)
        return false

    $(window).unload ->
      window.maptter.saveMap()
})

