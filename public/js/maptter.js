var router, square, _ref;
var __slice = Array.prototype.slice, __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
square = function(x) {
  return x * x;
};
router = function() {
  var args, func, path, pathname, route, _i, _len;
  args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
  pathname = location.pathname;
  for (_i = 0, _len = args.length; _i < _len; _i++) {
    route = args[_i];
    console.log(route);
    path = route.path;
    func = route.func;
    if (!(path && func)) {
      console.log(path);
      console.log(func);
    }
    if (!(path && func)) {
      return;
    }
    if (path === pathname || (path.test && path.test(pathname))) {
      return func();
    }
  }
};
if ((_ref = window.maptter) != null) {
  _ref;
} else {
  window.maptter = {
    friendIDs: [],
    moveTasks: {},
    initFriendsMap: function() {
      console.log(this);
      return $.get("/map/friends", "", __bind(function(friends, status) {
        var friend, icon;
        return this.friendIDs = (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = friends.length; _i < _len; _i++) {
            friend = friends[_i];
            icon = this.makeDraggableIcon(friend);
            $(".map").append(icon);
            _results.push(friend.user_id);
          }
          return _results;
        }).call(this);
      }, this));
    },
    makeDraggableIcon: function(friend) {
      return $("<img>").addClass("icon").data({
        friend_id: friend.friend_id,
        user_id: friend.user_id
      }).attr({
        src: friend.profile_image_url,
        alt: friend.screen_name,
        title: friend.screen_name
      }).css({
        top: friend.top,
        left: friend.left
      }).draggable({
        stack: ".icon",
        containment: "parent",
        stop: __bind(function(event, ui) {
          var user_id;
          user_id = ui.helper.data("user_id");
          return this.moveTasks[user_id] = {
            friend_id: ui.helper.data("friend_id"),
            top: ui.position.top,
            left: ui.position.left
          };
        }, this)
      });
    }
  };
};
router({
  path: "/",
  func: function() {
    console.log("test");
    return $(document).ready(function() {
      return window.maptter.initFriendsMap();
    });
  }
});