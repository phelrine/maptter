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
    path = route.path;
    func = route.func;
    if (!(path && func)) {
      return;
    }
    if (path === pathname || (path.test && path.test(pathname))) {
      return func();
    }
  }
};
if ((_ref = window.maptter) == null) {
  window.maptter = {
    friends: [],
    moveTasks: {},
    neighborIDs: [],
    neighborLength: 200,
    allTimeline: [],
    neighborsTimeline: [],
    initFriendsMap: function() {
      setInterval((__bind(function() {
        return this.saveMoveTasks();
      }, this)), 10000);
      setInterval((__bind(function() {
        return this.getTimeline();
      }, this)), 20000);
      $.get("/map/friends", "", __bind(function(friends, status) {
        var friend, icon;
        this.friends = (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = friends.length; _i < _len; _i++) {
            friend = friends[_i];
            icon = this.makeDraggableIcon(friend);
            $("#map").append(icon);
            _results.push(icon);
          }
          return _results;
        }).call(this);
        return this.updateNeighbors();
      }, this));
      return this.getTimeline();
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
          this.moveTasks[user_id] = {
            friend_id: ui.helper.data("friend_id"),
            top: ui.position.top,
            left: ui.position.left
          };
          return this.updateNeighbors();
        }, this)
      });
    },
    saveMoveTasks: function() {
      var id, params, value;
      if ($(".ui-draggable-dragging").length > 0 || $.isEmptyObject(this.moveTasks)) {
        return;
      }
      params = JSON.stringify((function() {
        var _ref2, _results;
        _ref2 = this.moveTasks;
        _results = [];
        for (id in _ref2) {
          value = _ref2[id];
          _results.push(value);
        }
        return _results;
      }).call(this));
      $.post("/map/move", {
        tasks: params
      }, __bind(function() {
        return this.moveTasks = {};
      }, this));
    },
    updateNeighbors: function() {
      var friend, length, squaredLeft, squaredTop, user, _i, _len, _ref2;
      user = this.friends[0];
      this.neighborIDs = [];
      _ref2 = this.friends;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        friend = _ref2[_i];
        squaredTop = square(parseFloat(user.css("top")) - parseFloat(friend.css("top")));
        squaredLeft = square(parseFloat(user.css("left")) - parseFloat(friend.css("left")));
        length = Math.sqrt(squaredTop + squaredLeft);
        if (length < this.neighborLength) {
          this.neighborIDs.push(friend.data("user_id"));
          friend.css("opacity", 1);
        } else {
          friend.css("opacity", 0.5);
        }
      }
      return this.updateNeighborsTimeline(this.allTimeline);
    },
    updateNeighborsTimeline: function(timeline, merge) {
      var diff, neighbor, neighborsTimeline, tweet, _i, _j, _k, _l, _len, _len2, _len3, _len4, _ref2, _results, _results2;
      if (merge == null) {
        merge = false;
      }
      neighborsTimeline = [];
      for (_i = 0, _len = timeline.length; _i < _len; _i++) {
        tweet = timeline[_i];
        _ref2 = this.neighborIDs;
        for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
          neighbor = _ref2[_j];
          if (neighbor === tweet.user.id_str) {
            neighborsTimeline.push(tweet);
          }
        }
      }
      if (merge === true) {
        diff = [];
        $.merge(diff, neighborsTimeline);
        this.neighborsTimeline = $.merge(neighborsTimeline, this.neighborsTimeline);
        diff.reverse();
        _results = [];
        for (_k = 0, _len3 = diff.length; _k < _len3; _k++) {
          tweet = diff[_k];
          _results.push($("div#mapTab .statusList").prepend(this.makeTweet(tweet)));
        }
        return _results;
      } else {
        this.neighborsTimeline = neighborsTimeline;
        $("div#mapTab .statusList").empty();
        _results2 = [];
        for (_l = 0, _len4 = neighborsTimeline.length; _l < _len4; _l++) {
          tweet = neighborsTimeline[_l];
          _results2.push($("div#mapTab .statusList").append(this.makeTweet(tweet)));
        }
        return _results2;
      }
    },
    makeTweet: function(tweet) {
      return $("<div>").addClass("status").append($("<img>").attr({
        src: tweet.user.profile_image_url
      }).addClass("image")).append($("<div>").text(tweet.user.screen_name).addClass("screenname")).append($("<div>").text(tweet.user.name).addClass("name")).append($("<div>").text(tweet.text).addClass("text")).append($("<a>").attr({
        href: "#"
      }).text("reply").addClass("reply").click((function() {
        $("#tweet-post-form input[name=in_reply_to_status_id]").val(tweet.id_str);
        return $("#tweet-post-form textarea[name=tweet]").val("@" + tweet.user.screen_name + " ");
      }))).append($("<div>").text("RT").addClass("RT")).append($("<div>").css({
        clear: "both"
      }));
    },
    getTimeline: function() {
      var diffTimeline, params;
      if ($(".ui-draggable-dragging").length > 0) {
        return;
      }
      params = {
        count: 100
      };
      diffTimeline = [];
      if (!(this.allTimeline.length === 0)) {
        params.since = this.allTimeline[0].created_at;
        params.count = 40;
      }
      $.get("twitter/timeline", params, __bind(function(timeline, status) {
        var latestID, latestTimeline, tweet, _i, _j, _len, _len2, _results;
        this.updateActiveUser(timeline);
        if (this.allTimeline.length === 0) {
          diffTimeline = timeline;
        } else {
          latestID = parseInt(this.allTimeline[0].id_str, 10);
          for (_i = 0, _len = timeline.length; _i < _len; _i++) {
            tweet = timeline[_i];
            if (latestID < parseInt(tweet.id_str, 10)) {
              diffTimeline.push(tweet);
            }
          }
        }
        if (diffTimeline.length > 0) {
          $(".tmp").remove();
        }
        latestTimeline = [];
        $.merge(latestTimeline, diffTimeline);
        this.allTimeline = $.merge(latestTimeline, this.allTimeline);
        this.updateNeighborsTimeline(diffTimeline, true);
        diffTimeline.reverse();
        _results = [];
        for (_j = 0, _len2 = diffTimeline.length; _j < _len2; _j++) {
          tweet = diffTimeline[_j];
          _results.push($("div#tlTab .statusList").prepend(this.makeTweet(tweet)));
        }
        return _results;
      }, this));
      return false;
    },
    updateActiveUser: function(timeline) {
      var friend, id, tweet, user, users, _i, _j, _len, _len2, _ref2, _results;
      if (timeline == null) {
        timeline = this.allTimeline;
      }
      users = {};
      for (_i = 0, _len = timeline.length; _i < _len; _i++) {
        tweet = timeline[_i];
        users[tweet.user.id_str] = tweet.user;
      }
      _ref2 = this.friends;
      for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
        friend = _ref2[_j];
        delete users[friend.data("user_id")];
      }
      $("#friendsList").empty();
      _results = [];
      for (id in users) {
        user = users[id];
        _results.push($("#friendsList").append($("<img>").draggable({
          revert: "invalid",
          opacity: 0.5
        }).data({
          profile: user
        }).attr({
          src: user.profile_image_url,
          alt: user.screen_name,
          alt: user.screen_name
        }).css({
          height: "48px",
          width: "48px"
        })));
      }
      return _results;
    }
  };
}
router({
  path: "/",
  func: function() {
    $(document).ready(function() {
      window.maptter.initFriendsMap();
      $("div#friendsScrollContainer").hide();
      $("#tlTabs").hide();
      $("#addFriendButton").click(function() {
        return $("div#friendsScrollContainer").toggle("slow");
      });
      $("#tlPanel").draggable({
        containment: "parent",
        stack: ".panel"
      });
      $("#tlToggleButton").click(function() {
        return $("#tlTabs").toggle("slow", function() {
          if ($(this).css("display") === "block") {
            return $(this).css("display", "table");
          }
        });
      });
      $("#tlTabs").tabs();
      $("#map").droppable({
        accept: ":not(.icon, .panel)",
        drop: function(event, ui) {
          var friend, mapOffset;
          ui.helper.draggable({
            disabled: true
          }).attr({
            src: "img/loading.gif"
          });
          friend = ui.helper.data("profile");
          mapOffset = $("#map").offset();
          return $.post("/map/add", {
            user_id: friend.id_str,
            top: ui.offset.top - mapOffset.top,
            left: ui.offset.left - mapOffset.left,
            profile: friend
          }, function(data, status) {
            var icon;
            $.extend(friend, data);
            icon = window.maptter.makeDraggableIcon(friend).hide();
            window.maptter.friends.push(icon);
            $("#map").append(icon);
            ui.helper.remove();
            icon.fadeIn('slow');
            return window.maptter.updateNeighbors();
          });
        }
      });
      $(".slider").slider({
        range: "min",
        min: 100,
        max: 600,
        value: window.maptter.neighborLength,
        slide: function(event, ui) {
          return $("#slider-length-display").text("Length: " + ui.value);
        },
        stop: function(event, ui) {
          window.maptter.neighborLength = ui.value;
          return window.maptter.updateNeighbors();
        }
      });
      return $("#tweet-post-form").submit(function() {
        $.post("/twitter/update", $("#tweet-post-form").serialize(), function(tweet, status) {
          $("#tweet-post-form textarea[name=tweet]").val("");
          return $(".timeline").prepend(maptter.makeTweet(tweet).addClass("tmp"));
        });
        return false;
      });
    });
    return $(window).unload(function() {
      return window.maptter.saveMoveTasks();
    });
  }
});