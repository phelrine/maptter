square = (x) -> x * x
router = (args...) ->
  pathname = location.pathname
  for route in args
    console.log route
    path = route.path
    func = route.func
    unless path and func
      console.log path
      console.log func
    return unless path and func
    return func() if path == pathname or (path.test and path.test pathname)

window.maptter ?=
  friendIDs: []
  moveTasks: {}
  initFriendsMap: ->
    console.log this
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

router({
  path: "/"
  func: ->
    console.log "test"
    $(document).ready ->
      window.maptter.initFriendsMap()
})
