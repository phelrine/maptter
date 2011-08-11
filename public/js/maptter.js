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
    user: null,
    friends: [],
    saveTasks: {},
    distances: {},
    neighborLength: 150,
    allTimeline: [],
    mapTimeline: [],
    refreshLockCount: 0,
    initFriendsMap: function() {
      setInterval((__bind(function() {
        return this.saveMap();
      }, this)), 10000);
      setInterval((__bind(function() {
        return this.getTimeline();
      }, this)), 20000);
      return $.get("/map/friends", "", __bind(function(friends, status) {
        var friend, icon, _i, _len, _ref2;
        for (_i = 0, _len = friends.length; _i < _len; _i++) {
          friend = friends[_i];
          icon = this.makeDraggableIcon(friend, this.user != null);
          if ((_ref2 = this.user) == null) {
            this.user = icon;
          }
          $("#map").append(icon);
          this.friends.push(icon);
        }
        this.updateDistances();
        return this.getTimeline();
      }, this));
    },
    makeDraggableIcon: function(friend, hasRemoveUI) {
      if (hasRemoveUI == null) {
        hasRemoveUI = true;
      }
      return $("<div>").addClass("mapIcon").attr({
        id: "user_" + friend.user_id
      }).data({
        friend_id: friend.friend_id,
        user_id: friend.user_id
      }).css({
        position: "absolute",
        top: friend.top + "px",
        left: friend.left + "px"
      }).draggable({
        stack: ".mapIcon",
        containment: "parent",
        start: __bind(function(event, ui) {
          return $(".qtip").qtip('hide');
        }, this),
        stop: __bind(function(event, ui) {
          var friend_id;
          friend_id = ui.helper.data("friend_id");
          this.saveTasks[friend_id] = {
            friend_id: ui.helper.data("friend_id"),
            type: "move",
            top: ui.position.top,
            left: ui.position.left
          };
          return this.updateDistances();
        }, this)
      }).append($("<img>").addClass("icon").attr({
        src: friend.profile_image_url,
        alt: friend.screen_name,
        title: friend.screen_name
      }).qtip({
        content: {
          title: {
            text: friend.name,
            button: "Close"
          },
          text: function(api) {
            var text, _ref2;
            text = $("<a>").text("@" + friend.screen_name).attr({
              href: "http://twitter.com/#!/" + friend.screen_name,
              target: "_blank"
            }).after($("<p>").text((_ref2 = friend.status) != null ? _ref2.text : void 0)).after($("<a>").text("返信").attr({
              href: "#tweetTextarea"
            }).click(function() {
              return $("#tweetTextarea").text("@" + friend.screen_name);
            }));
            if (hasRemoveUI) {
              text = text.after($("<a>").text("アイコンを削除").attr({
                href: "#"
              }).click(__bind(function() {
                var parent, self;
                self = window.maptter;
                self.saveTasks[friend.friend_id] = {
                  type: "remove",
                  friend_id: friend.friend_id
                };
                $.each(self.friends, function(index, elem) {
                  if ($(elem).data("friend_id") === friend.friend_id) {
                    self.friends.splice(index, 1);
                    return false;
                  }
                });
                self.updateDistances();
                $("#ui-tooltip-profile").qtip('hide');
                parent = $(this).parent();
                parent.fadeOut('slow');
                return parent.empty();
              }, this)));
            }
            return text;
          }
        },
        style: {
          classes: "ui-tooltip-shadow ui-tooltip-light profile"
        },
        show: {
          solo: true,
          event: "mouseenter",
          delay: 300
        },
        hide: {
          event: "click unfocus"
        },
        position: {
          my: "bottom left",
          at: "top left"
        }
      }));
    },
    saveMap: function() {
      var id, params, value;
      if ($(".ui-draggable-dragging").length > 0 || $.isEmptyObject(this.saveTasks)) {
        return;
      }
      params = JSON.stringify((function() {
        var _ref2, _results;
        _ref2 = this.saveTasks;
        _results = [];
        for (id in _ref2) {
          value = _ref2[id];
          _results.push(value);
        }
        return _results;
      }).call(this));
      this.saveTasks = {};
      $.post("/map/save", {
        tasks: params,
        token: $("#token").val()
      });
    },
    updateDistances: function() {
      var distance, friend, squaredLeft, squaredTop, user_id, _base, _i, _len, _ref2, _ref3;
      this.distances = {};
      _ref2 = this.friends;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        friend = _ref2[_i];
        user_id = friend.data("user_id");
        squaredTop = square(parseFloat(this.user.css("top")) - parseFloat(friend.css("top")));
        squaredLeft = square(parseFloat(this.user.css("left")) - parseFloat(friend.css("left")));
        distance = Math.sqrt(squaredTop + squaredLeft);
        if ((_ref3 = (_base = this.distances)[user_id]) == null) {
          _base[user_id] = distance;
        }
        if (distance < this.distances[user_id]) {
          this.distances[user_id] = distance;
        }
        distance = this.distances[user_id];
        if (distance < this.neighborLength) {
          friend.css("opacity", 1);
        } else {
          friend.css("opacity", 0.5);
        }
      }
      return this.updateMapTimeline(this.allTimeline);
    },
    updateMapTimeline: function(timeline, merge) {
      var diff, recentMapTimeline, tweet, _i, _j, _len, _len2, _ref2, _results, _results2;
      if (merge == null) {
        merge = false;
      }
      recentMapTimeline = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = timeline.length; _i < _len; _i++) {
          tweet = timeline[_i];
          if (this.distances[tweet.user.id_str] == null) {
            continue;
          }
          _results.push(tweet);
        }
        return _results;
      }).call(this);
      if (merge === true) {
        diff = [];
        $.merge(diff, recentMapTimeline);
        this.mapTimeline = $.merge(recentMapTimeline, this.mapTimeline);
        diff.reverse();
        _results = [];
        for (_i = 0, _len = diff.length; _i < _len; _i++) {
          tweet = diff[_i];
          $("#user_" + tweet.user.id_str).qtip({
            content: tweet.text,
            style: {
              classes: "ui-tooltip-shadow ui-tooltip-light"
            },
            show: {
              event: false,
              ready: true,
              effect: function(offset) {
                var self;
                self = this;
                $(this).show();
                setTimeout((function() {
                  return $(self).hide();
                }), 5000);
                return false;
              }
            }
          });
          _results.push($("div#mapTab .statusList").prepend(this.makeMapTweet(tweet)));
        }
        return _results;
      } else {
        this.mapTimeline = recentMapTimeline;
        $("div#mapTab .statusList").empty();
        _ref2 = this.mapTimeline;
        _results2 = [];
        for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
          tweet = _ref2[_j];
          _results2.push($("div#mapTab .statusList").append(this.makeMapTweet(tweet)));
        }
        return _results2;
      }
    },
    makeMapTweet: function(tweet) {
      var length, _ref2;
      length = (_ref2 = this.distances[tweet.user.id_str]) != null ? _ref2 : -1;
      if (length < 0 || length < this.neighborLength) {
        return this.makeTweet(tweet);
      } else {
        return $("<li>").addClass("status iconOnly").append($("<img>").attr({
          src: tweet.user.profile_image_url
        }));
      }
    },
    makeTweet: function(tweet) {
      var dom;
      dom = $("<li>").addClass("status").append($("<div>").addClass("image").append($("<img>").attr({
        src: tweet.user.profile_image_url
      }))).append($("<div>").addClass("content").append($("<span>").text(tweet.user.screen_name).addClass("screenname")).append($("<span>").text(tweet.user.name).addClass("name")).append($("<div>").addClass("text").html(twttr.txt.autoLink(twttr.txt.htmlEscape(tweet.text)))).append($("<div>").addClass("tool").append($("<a>").addClass("timestamp").attr({
        href: "http://twitter.com/#!/" + tweet.user.screen_name + "/status/" + tweet.id_str,
        target: "_blank",
        title: new Date(tweet.created_at)
      }).timeago()).append($("<a>").attr({
        href: "#tweetTextarea"
      }).text("reply").addClass("reply").click(function() {
        $("#tweetPostForm input[name=in_reply_to_status_id]").val(tweet.id_str);
        $("#tweetPostForm textarea[name=tweet]").val("@" + tweet.user.screen_name + " ").focus();
        return false;
      })).append(this.makeFavoriteElement(tweet)))).hover((function() {
        return $(this).find("div.tool").css({
          visibility: "visible"
        });
      }), (function() {
        return $(this).find("div.tool").css({
          visibility: "hidden"
        });
      }));
      dom.find(".text a").attr({
        target: "_blank"
      });
      return dom;
    },
    makeFavoriteElement: function(tweet) {
      var fav;
      fav = $("<a>").attr({
        href: "#"
      }).text("favorite").addClass("favorite");
      if (tweet.favorited) {
        fav.addClass("favorited");
      }
      fav.click(function() {
        var api;
        api = $(this).hasClass("favorited") ? "delete" : "create";
        return $.post("/twitter/favorite/" + api, {
          tweet_id: tweet.id_str,
          token: $("#token").val()
        }, function(response, status) {
          if (api === "create") {
            fav.addClass("favorited");
          } else {
            fav.removeClass("favorited");
          }
          return false;
        });
      });
      return fav;
    },
    getTimeline: function() {
      var diffTimeline, params;
      if ($(".ui-draggable-dragging").length > 0) {
        return;
      }
      if (this.refreshLockCount > 0) {
        return;
      }
      params = {
        count: 80
      };
      diffTimeline = [];
      if (!(this.allTimeline.length === 0)) {
        params.since = this.allTimeline[0].created_at;
        params.count = 40;
      }
      $(".friendIcon").remove();
      $(".loading").show();
      $.get("twitter/timeline", params, __bind(function(timeline, status) {
        var latestID, latestTimeline, tweet, _i, _j, _len, _len2;
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
        this.updateMapTimeline(diffTimeline, true);
        diffTimeline.reverse();
        for (_j = 0, _len2 = diffTimeline.length; _j < _len2; _j++) {
          tweet = diffTimeline[_j];
          $("div#timelineTab .statusList").prepend(this.makeTweet(tweet));
        }
        return $(".loading").hide();
      }, this));
      return false;
    },
    updateActiveUser: function(timeline) {
      var friend, id, tweet, user, user_id, users, _i, _j, _len, _len2, _ref2, _results;
      if (timeline == null) {
        timeline = this.allTimeline;
      }
      users = {};
      for (_i = 0, _len = timeline.length; _i < _len; _i++) {
        tweet = timeline[_i];
        user_id = tweet.user.id_str;
        tweet.user.status = {};
        tweet.user.status.text = tweet.text;
        users[user_id] = tweet.user;
      }
      _ref2 = this.friends;
      for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
        friend = _ref2[_j];
        delete users[friend.data("user_id")];
      }
      _results = [];
      for (id in users) {
        user = users[id];
        _results.push($("#friendsList").append($("<img>").addClass("friendIcon").draggable({
          revert: "invalid",
          opacity: 0.5
        }).data({
          profile: user
        }).attr({
          src: user.profile_image_url,
          alt: user.screen_name,
          title: user.screen_name
        }).hover((function() {
          $("#map").addClass("addFriend");
          return $("#map strong").show();
        }), (function() {
          $("#map strong").hide();
          return $("#map").removeClass("addFriend");
        }))));
      }
      return _results;
    }
  };
}
router({
  path: "/",
  func: function() {
    $(document).ready(function() {
      var handle;
      window.maptter.initFriendsMap();
      $("#addFriendButton").click(function() {
        return $("#friendsList").slideToggle("slow");
      });
      $("#timelineTabs").tabs();
      $("#map").droppable({
        accept: ":not(.mapIcon)",
        drop: function(event, ui) {
          var friend, mapOffset;
          window.maptter.refreshLockCount++;
          ui.helper.draggable({
            disabled: true
          }).attr({
            src: "img/loading.gif"
          });
          friend = ui.helper.data("profile");
          mapOffset = $("#map").offset();
          return $.ajax({
            url: "/map/add",
            type: "POST",
            data: {
              token: $("#token").val(),
              user_id: friend.id_str,
              top: ui.offset.top - mapOffset.top,
              left: ui.offset.left - mapOffset.left,
              profile: friend
            },
            error: function(request, status, error) {
              window.maptter.refreshLockCount--;
              return ui.helper.remove();
            },
            success: function(data, status) {
              var icon;
              window.maptter.refreshLockCount--;
              $.extend(friend, data);
              icon = window.maptter.makeDraggableIcon(friend).hide();
              $("#map").append(icon);
              window.maptter.friends.push(icon);
              ui.helper.remove();
              icon.fadeIn('slow');
              return window.maptter.updateDistances();
            }
          });
        }
      });
      handle = null;
      $("#rangeSlider").slider({
        orientation: "vertical",
        range: "max",
        min: 100,
        max: 400,
        value: window.maptter.neighborLength,
        slide: function(event, ui) {
          return handle.qtip("option", "content.text", ui.value);
        },
        stop: function(event, ui) {
          window.maptter.neighborLength = ui.value;
          return window.maptter.updateDistances();
        }
      });
      if (handle == null) {
        handle = $(".ui-slider-handle", this);
      }
      handle.qtip({
        content: "range",
        position: {
          my: 'left center',
          at: 'right center',
          container: handle,
          adjust: {
            x: handle.width() / 2,
            y: -handle.height() / 2
          }
        },
        hide: {
          delay: 1000
        },
        style: {
          classes: "ui-tooltip-slider",
          widget: true
        }
      });
      return $("#tweetPostForm").submit(function() {
        $.post("/twitter/update", $("#tweetPostForm").serialize(), function(tweet, status) {
          var tweetElem;
          tweetElem = window.maptter.makeTweet(tweet).addClass("tmp");
          $("div#timelineTab .statusList").prepend(tweetElem.clone());
          return $("div#mapTab .statusList").prepend(tweetElem);
        });
        $("#tweetPostForm textarea[name=tweet]").val("");
        return false;
      });
    });
    return $(window).unload(function() {
      return window.maptter.saveMap();
    });
  }
});