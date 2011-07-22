Math.square = function(x){
    return x * x;
}

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
    updateNeighbors: function(){
	var self = this;
	var user = $("#user-icon");
	var friends = $(".icon");
	var neighborIDs = [];
	$.each(friends, function(index, friend){
	    var squaredTop = Math.square(parseFloat(user.css("top")) - parseFloat($(friend).css("top")));
	    var squaredLeft = Math.square(parseFloat(user.css("left")) - parseFloat($(friend).css("left")));
	    var length = Math.sqrt(squaredTop + squaredLeft);
	    if(length < 200){
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
	if(self.allTimeline.length != 0){
	    params.since = self.allTimeline[0].created_at
	    params.count = 40;
	}
	$.get("/twitter/timeline", params, function(timeline, status){
	    var diffTimeline = []
	    var timelineLength = self.allTimeline.length;
	    self.updateActiveUsers(timeline);
	    if(timelineLength == 0){
		diffTimeline = timeline;
	    }else{
		var latestTweetID = parseInt(self.allTimeline[0].id_str);
		var pos = 0;
		$.each(timeline, function(index, tweet){
		    if(latestTweetID < parseInt(tweet.id_str)){
			diffTimeline.push(tweet);
		    }
		});
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
	    timeline == this.allTimeline;
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
		$("<img>").draggable()
		    .data({profile: user})
		    .attr({
			src: user.profile_image_url,
			alt: user.screen_name,
			title: user.screen_name
		    })
		    .css({
			height: "48px",
			width: "48px",
		    })
	    );
	});
    },
    updateNeighborsTimeline: function(timeline, merge){
	var self = this;
	if(merge == undefined){
	    merge == false;
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
	for(var dummy in self.moveTasks){
	    $.post("/map/move",
		   {tasks: JSON.stringify($.map(self.moveTasks, function(value, key){return value;}))},
		   function(data, status){
		       self.moveTasks = {};
		   });
	    return
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
	    .append($("<div>").html(tweet.user.screen_name + " " + tweet.user.name))
	    .append($("<div>").html(tweet.text))
	    .append($("<a>").attr({href: "#"}).html("reply").click(function(){
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
		    var friend = ui.helper.data("profile");
		    var mapOffset = $(".map").offset();
		    if(maptter.friendIDs.indexOf(friend.id_str) == -1){
			maptter.friendIDs.push(friend.id_str);
		    }
		    $.post("/map/add", {
			user_id: friend.id_str,
			top: ui.offset.top - mapOffset.top,
			left: ui.offset.left - mapOffset.left
		    },function(data, status){
			$.extend(friend, data);
			$(".map").append(maptter.makeDraggableIcon(friend));
			maptter.updateNeighbors();
			ui.helper.remove();
		    });
		}
	    });
	    $("#tweet-post-form").submit(function(){
		$.post("/twitter/update", $('#tweet-post-form').serialize());
		return false;
	    });
	});
    }
});
