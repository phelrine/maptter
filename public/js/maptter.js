Math.square = function(x){
    return x * x;
};

if(!window.maptter) window.maptter = {
    route: function() {
	var pathname = location.pathname;
	$.each(arguments, function(key){
	    var path = this.path;
	    var func = this.func;
	
	    if(!path || !func) return;
	    if(pathname === path || (path.test && path.test(pathname)))
		func();
	});
    },
    friendIDs: [],
    initFriendsMap: function(){
	var self = this;
	$.get("/map/friends", "", function(friends, status){
	    $.each(friends, function(index, friend){
		var icon = self.makeDraggableIcon(friend);
		if(index == 0){
		    icon.attr("id", "user-icon");
		}
		$(".map").append(icon);
		self.friendIDs.push(friend.user_id);
	    });
	    self.updateNeighbors();
	    self.getTimeline();
	});
    },		  
    neighborIDs: [],
    neighborLength: 200,
    updateNeighbors: function(){
	var self = this;
	var user = $("#user-icon");
	var friends = $(".icon");
	var neighborIDs = [];
	$.each(friends, function(index, friend){
	    var squaredTop = Math.square(parseFloat(user.css("top")) - parseFloat($(friend).css("top")));
	    var squaredLeft = Math.square(parseFloat(user.css("left")) - parseFloat($(friend).css("left")));
	    var length = Math.sqrt(squaredTop + squaredLeft);
	    if(length < self.neighborLength){
		neighborIDs.push($(friend).data("user_id"));
	    }
	});
	self.neighborIDs = neighborIDs;
	self.updateNeighborsTimeline(self.allTimeline);
    },
    allTimeline: [],
    neighborsTimeline: [],
    getTimeline: function(){
	var self = window.maptter;
	var params = {count: 100};
	if($(".ui-draggable-dragging").length > 0) return;
	if(self.allTimeline.length != 0){
	    params.since = self.allTimeline[0].created_at;
	    params.count = 40;
	}
	$.get("/twitter/timeline", params, function(timeline, status){
	    var diffTimeline = [];
	    var timelineLength = self.allTimeline.length;
	    self.updateActiveUsers(timeline);
	    if(timelineLength == 0){
		diffTimeline = timeline;
	    }else{
		var latestTweetID = parseInt(self.allTimeline[0].id_str, 10);
		var pos = 0;
		$.each(timeline, function(index, tweet){
		    if(latestTweetID < parseInt(tweet.id_str, 10)){
			diffTimeline.push(tweet);
		    }
		});
	    }
	    if(diffTimeline.length > 0){
		$(".tmp").remove();
	    }
	    var latestTimeline = [];
	    $.merge(latestTimeline, diffTimeline);
	    $.merge(latestTimeline, self.allTimeline);
	    self.allTimeline = latestTimeline;
	    self.updateNeighborsTimeline(diffTimeline, true);
	});
    },
    updateActiveUsers: function(timeline){
	var self = this;
	var users = {};
	if(timeline == undefined){
	    timeline = this.allTimeline;
	}
	$.each(timeline, function(index, tweet){
	    users[tweet.user.id] = tweet.user;
	});
	$.each(self.friendIDs, function(index, friendID){
	    delete users[friendID];
	});
	$(".friends").empty();
	$.each(users, function(key, user){
	    $(".friends").append(
		$("<img>").draggable({
		    revert: "invalid",
		    opacity: 0.5,
		})
		    .data({profile: user})
		    .attr({
			src: user.profile_image_url,
			alt: user.screen_name,
			title: user.screen_name
		    })
		    .css({
			height: "48px",
			width: "48px"
		    })
	    );
	});
    },
    updateNeighborsTimeline: function(timeline, merge){
	var self = this;
	if(merge == undefined){
	    merge = false;
	}
	var neighborsTimeline = [];
	$.each(timeline, function(index, tweet){
	    $.each(self.neighborIDs, function(index, neighbor){
		if(neighbor == tweet.user.id_str){
		    neighborsTimeline.push(tweet);
		}
	    });
	});
	if(merge == true){
	    var diff = [];
	    $.merge(diff, neighborsTimeline);
	    $.merge(neighborsTimeline, self.neighborsTimeline);
	    self.neighborsTimeline = neighborsTimeline;
	    diff.reverse();
	    $.each(diff, function(index, tweet){
		$(".timeline").prepend(self.makeTweet(tweet));
	    });
	}else{
	    self.neighborsTimeline = neighborsTimeline;
	    $(".timeline").empty();
	    $.each(neighborsTimeline, function(index, tweet){
		$(".timeline").append(self.makeTweet(tweet));
	    });
	}
    },
    moveTasks: {},
    saveMoveTasks: function(){
	var self = window.maptter;
	if($(".ui-draggable-dragging").length > 0) return;
	for(var dummy in self.moveTasks){
	    $.post("/map/move",
		   {tasks: JSON.stringify($.map(self.moveTasks, function(value, key){return value;}))},
		   function(data, status){
		       self.moveTasks = {};
		   });
	    return;
	}
    },
    makeDraggableIcon: function(data){
	var self = this;
	return $("<img>").addClass("icon")
	    .data({friend_id: data.friend_id, user_id: data.id_str})
	    .attr({
		src: data.profile_image_url,
		alt: data.screen_name,
		title: data.screen_name,
	    })
	    .css({
		top: data.top,
		left: data.left
	    })
	    .draggable({
		stack: ".icon",
		stop: function(e, ui){
		    var friend = $(this);
		    self.moveTasks[friend.data("user_id")] = {
			friend_id: friend.data("friend_id"),
			top: ui.position.top,
			left: ui.position.left
		    };
		    self.updateNeighbors();
		},
		containment: "parent"
	    });
    },
    makeTweet: function(tweet){
	return $("<div>")
	    .append($("<img>").attr({src: tweet.user.profile_image_url}).css({float: "left"}))
	    .append($("<div>").text(tweet.user.screen_name + " " + tweet.user.name))
	    .append($("<div>").text(tweet.text))
	    .append($("<a>").attr({href: "#"}).text("reply").click(function(){
		$("#tweet-post-form input[name=in_reply_to_status_id]").val(tweet.id_str);
		$("#tweet-post-form textarea[name=tweet]").val("@" + tweet.user.screen_name + " ");
	    }))
	    .append($("<div>").css({clear: "both"}));
    }
};

window.maptter.route({
    path: "/",
    func: function(){
	$(document).ready(function(){
	    maptter.initFriendsMap();
	    setInterval(maptter.getTimeline, 30000);
	    setInterval(maptter.saveMoveTasks, 10000);
	    $(".map").droppable({
		accept: ":not(.icon)",
		drop: function(event, ui){
		    ui.helper.draggable({disabled: true}).attr({src: "img/loading.gif"});
		    var friend = ui.helper.data("profile");
		    var mapOffset = $(".map").offset();
		    if(maptter.friendIDs.indexOf(friend.id_str) == -1){
			maptter.friendIDs.push(friend.id_str);
		    }
		    $.post("/map/add", {
			user_id: friend.id_str,
			top: ui.offset.top - mapOffset.top,
			left: ui.offset.left - mapOffset.left,
			profile: friend
		    }, function(data, status){
			$.extend(friend, data);
			var icon = maptter.makeDraggableIcon(friend).hide()
			$(".map").append(icon);
			ui.helper.remove();
			icon.fadeIn('slow');
			maptter.updateNeighbors();
		    });
		}
	    });
	    $("#tweet-post-form").submit(function(){
		$.post("/twitter/update", $('#tweet-post-form').serialize(), function(tweet, status){
		    $("#tweet-post-form textarea[name=tweet]").val("");
		    $(".timeline").prepend(maptter.makeTweet(tweet).addClass("tmp"));
		});
		return false;
	    });
	    $(".slider").slider({
		range: "min",
		min: 100,
		max: 600,
		value: maptter.neighborLength,
		slide: function(event, ui){
		    $("#slider-length-display").text("Length: " + ui.value);
		},
		stop: function(event, ui){
		    maptter.neighborLength = ui.value;
		    maptter.updateNeighbors();
		}
	    });
	});

	$(window).unload(function(){
	    maptter.saveMoveTasks();
	});
    }
});
