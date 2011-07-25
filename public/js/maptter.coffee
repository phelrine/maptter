square = (x) -> x * x
router = (args...) ->
  pathname = location.pathname
  for route in args
    path = route.path
    func = route.func
    return unless path and func
    return func() if path == pathname or (path.test and path.test pathname)

window.maptter ?=
  friendIDs: []
  moveTasks: {}

  initFriendsMap: ->
    setInterval (=> @saveMoveTasks()), 10000
    $.get "/map/friends", "", (friends, status) =>
      @friendIDs = for friend in friends
        icon = @makeDraggableIcon friend
        $(".map").append icon
        friend.user_id

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
      )

  saveMoveTasks: ->
    return if $(".ui-draggable-dragging").length > 0 or $.isEmptyObject @moveTasks
    params = JSON.stringify(for id, value of @moveTasks
        value
    )
    $.post "/map/move", tasks: params, =>
        @moveTasks = {}
    return

router({
  path: "/"
  func: ->
    $(document).ready ->
      window.maptter.initFriendsMap()
    $(window).unload ->
      window.maptter.saveMoveTasks()
})
