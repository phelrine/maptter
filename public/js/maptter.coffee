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
  friends: []
  saveTasks: {}
  distances: {}
  neighborLength: 150
  allTimeline: []
  mapTimeline: []
  refreshLockCount: 0

  initFriendsMap: ->
    setInterval (=> @saveMap()), 10000
    setInterval (=> @getTimeline()), 20000

    $.get "/map/friends", "", (friends, status) =>
      for friend in friends
        icon = @makeDraggableIcon friend, @user?
        @user ?= icon
        $("#map").append icon
        @friends.push icon
      @updateDistances()
      @getTimeline()

  makeDraggableIcon: (friend, hasRemoveUI = true) ->
    return $("<div>")
      .addClass("mapIcon")
      .attr(id: "user_" + friend.user_id)
      .data(
        friend_id: friend.friend_id
        user_id: friend.user_id
      )
      .css(
        position: "absolute"
        top: friend.top + "px"
        left: friend.left + "px"
      )
      .draggable(
        stack: ".mapIcon"
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
      )
      .append(
        $("<img>").addClass("icon").attr(
          src: friend.profile_image_url
          alt: friend.screen_name
          title: friend.screen_name
        )
        .qtip(
          content:
            title:
              text: friend.name
              button: "Close"
            text: (api) ->
              text = $("<a>").text("@" + friend.screen_name)
                .attr(
                  href: "http://twitter.com/#!/"+friend.screen_name
                  target: "_blank"
                )
                .after($("<p>").text(friend.status?.text))
                .after($("<a>").text("返信").attr(href: "#tweetTextarea").click(-> $("#tweetTextarea").text("@" + friend.screen_name)))
              if hasRemoveUI
                text = text.after(
                  $("<a>").text("アイコンを削除").attr(href: "#").click =>
                    self = window.maptter
                    self.saveTasks[friend.friend_id] =
                      type: "remove"
                      friend_id: friend.friend_id
                    $.each self.friends, (index, elem) ->
                      if $(elem).data("friend_id") == friend.friend_id
                        self.friends.splice(index, 1)
                        return false
                    self.updateDistances()
                    $("#ui-tooltip-profile").qtip('hide')
                    parent = $(this).parent()
                    parent.fadeOut('slow')
                    parent.empty()
                )
              return text
          style:
            classes: "ui-tooltip-shadow ui-tooltip-light profile"
          show:
            solo: true
            event: "mouseenter"
            delay: 300
          hide:
            event: "click unfocus"
          position:
            my: "bottom left"
            at: "top left"
        ))

  saveMap: ->
    return if $(".ui-draggable-dragging").length > 0 or $.isEmptyObject @saveTasks
    params = JSON.stringify(for id, value of @saveTasks
        value
    )
    @saveTasks = {}
    $.post "/map/save",
      tasks: params
      token: $("#token").val()
    return

  updateDistances: ->
    @distances = {}
    for friend in @friends
      user_id = friend.data "user_id"
      squaredTop = square(parseFloat(@user.css "top") - parseFloat(friend.css "top"))
      squaredLeft = square(parseFloat(@user.css "left") - parseFloat(friend.css "left"))
      distance = Math.sqrt(squaredTop + squaredLeft)
      @distances[user_id] ?= distance
      @distances[user_id] = distance if distance < @distances[user_id]
      distance = @distances[user_id]
      if distance < @neighborLength
        friend.css "opacity", 1
      else
        friend.css "opacity", 0.5

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
        $("#user_" + tweet.user.id_str).qtip
          content: tweet.text
          style:
            classes: "ui-tooltip-shadow ui-tooltip-light"
          show:
            event: false
            ready: true
            effect: (offset)->
              self = this
              $(this).show()
              setTimeout((-> $(self).hide()), 5000)
              return false
        $("div#mapTab .statusList").prepend(@makeMapTweet tweet)
    else
      @mapTimeline = recentMapTimeline
      $("div#mapTab .statusList").empty()
      for tweet in @mapTimeline
        $("div#mapTab .statusList").append(@makeMapTweet tweet)

  makeMapTweet: (tweet) ->
    length = @distances[tweet.user.id_str] ? -1
    return if length < 0 or length < @neighborLength
        @makeTweet(tweet)
      else
        $("<li>").addClass("status iconOnly").append(
          $("<img>").attr(src: tweet.user.profile_image_url)
            .after($("<div>").addClass("content")
              .append($("<span>").text(tweet.user.screen_name +
                " がツイートしました")))
        ).append($("<div>").addClass("clear"))

  makeTweet: (tweet) ->
    dom = $("<li>").addClass("status")
      .append($("<div>").addClass("image").append($("<img>").attr(src: tweet.user.profile_image_url)))
      .append($("<div>").addClass("content")
        .append($("<span>").text(tweet.user.screen_name).addClass("screenname"))
        .append($("<span>").text(tweet.user.name).addClass("name"))
        .append($("<div>").addClass("text").html(
          twttr.txt.autoLink(twttr.txt.htmlEscape(tweet.text))
        ))
        .append($("<div>").addClass("tool")
          .append($("<a>").addClass("timestamp").attr(
              href: "http://twitter.com/#!/" + tweet.user.screen_name + "/status/" + tweet.id_str
              target: "_blank"
              title: new Date(tweet.created_at)
            ).timeago()
          )
          .append($("<a>").attr(href: "#tweetTextarea").text("reply").addClass("reply").click(->
            $("#tweetPostForm input[name=in_reply_to_status_id]").val(tweet.id_str)
            $("#tweetPostForm textarea[name=tweet]").val("@" + tweet.user.screen_name + " ").focus()
            return false
          ))
          .append(@makeFavoriteElement(tweet))
        ))
      .hover((-> $(this).find("div.tool").css(visibility: "visible")), (-> $(this).find("div.tool").css(visibility: "hidden")))
    dom.find(".text a").attr(target: "_blank")
    dom

  makeFavoriteElement: (tweet) ->
    fav = $("<a>").attr(href: "#").text("favorite").addClass("favorite")
    fav.addClass("favorited") if tweet.favorited
    fav.click(->
      api = if $(this).hasClass("favorited") then "delete" else "create"
      $.post "/twitter/favorite/" + api,
        tweet_id: tweet.id_str
        token: $("#token").val(),
         (response, status)->
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

    $(".friendIcon").remove()
    $(".loading").show()

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
      $(".loading").hide()
    false

  updateActiveUser: (timeline = @allTimeline)->
    users = {}

    for tweet in timeline
      user_id = tweet.user.id_str
      tweet.user.status = {}
      tweet.user.status.text = tweet.text
      users[user_id] = tweet.user

    for friend in @friends
      delete users[friend.data("user_id")]


    for id, user of users
      $("#friendsList").append(
        $("<img>").addClass("friendIcon").draggable(
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
        accept: ":not(.mapIcon)"
        drop: (event, ui) ->
          window.maptter.refreshLockCount++
          ui.helper.draggable(disabled: true).attr(src: "img/loading.gif")
          friend = ui.helper.data("profile")
          mapOffset = $("#map").offset()
          $.ajax {
            url: "/map/add"
            type: "POST"
            data:
              token: $("#token").val()
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
              window.maptter.friends.push icon
              ui.helper.remove()
              icon.fadeIn 'slow'
              window.maptter.updateDistances()
          }

      handle = null
      $("#rangeSlider").slider(
        range: "min"
        min: 100
        max: 400
        value: window.maptter.neighborLength
        slide: (event, ui) ->
          handle.qtip("option", "content.text", ui.value)
        stop: (event, ui) ->
          window.maptter.neighborLength = ui.value
          window.maptter.updateDistances()
      )

      handle ?= $(".ui-slider-handle", this)
      handle.qtip(
        content: "range"
        position:
          my: 'bottom center',
          at: 'top center',
          container: handle
          adjust:
            x: handle.width()/2
            y: -handle.height()/2
        hide:
          delay: 1000
        style:
          classes: "ui-tooltip-slider"
          widget: true
      )
      $("#tweetPostForm").submit ->
        $.post "/twitter/update", $("#tweetPostForm").serialize(), (tweet, status)->
          tweetElem = window.maptter.makeTweet(tweet).addClass("tmp")
          $("div#timelineTab .statusList").prepend(tweetElem.clone())
          $("div#mapTab .statusList").prepend(tweetElem)
        $("#tweetPostForm textarea[name=tweet]").val ""
        return false

    $(window).unload ->
      window.maptter.saveMap()
})

