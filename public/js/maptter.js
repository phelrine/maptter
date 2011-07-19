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
    initFriendsMap: function(){
	maptter.getFriends(function(friends){
	    $.each(friends, function(index, value){
		var icon = maptter.makeDraggableIcon(value);
		if(index == 0){
		    icon.attr("id", "user-icon");
		}
		$(".map").append(icon);
	    });
	    maptter.updateNeighbor();
	    maptter.getTimeline();
	});
    },		  
    getFriends: function(callback){
	var self = this;
	$.get("/map/friends", "", function(data, status){
	    callback(data, status);
	});
    },
    neighbors: [],
    updateNeighbor: function(){
	var self = this;
	var user = $("#user-icon");
	var friends = $(".icon");
	var neighbors = [];
	$.each(friends, function(index, friend){
	    var squaredTop = Math.square(parseFloat(user.css("top")) - parseFloat(friends.css("top")));
	    var squaredLeft = Math.square(parseFloat(user.css("left")) - parseFloat(friends.css("left")));
	    var length = Math.sqrt(squaredTop + squaredLeft);
	    if(length < 100){
		neighbors.push($(friend).data("user_id"));
	    }
	});
	self.neighbors = neighbors;
	self.updateNeighborTimeline(self.allTimeline);
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
		    $.post("/map/move", {
			friend_id: $(this).data("friend_id"),
			top: ui.position.top,
			left: ui.position.left
		    }, function(data, status){
			this.top = data.top;
			this.left = data.left;
			self.updateNeighbor();
		    });
		},
		containment: "parent"
	    });
    },
    allTimeline: [],
    neighborsTimeline: [],
    getTimeline: function(){
	var self = window.maptter;
	$.get("/twitter/timeline", "", function(timeline, status){
	    var diffTimeline = []
	    var timelineLength = self.allTimeline.length;
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
	    self.updateNeighborTimeline(diffTimeline, true);
	});
    },
    updateNeighborTimeline: function(timeline, merge){
	var self = this;
	if(merge == undefined){
	    merge == false;
	}
	var neighborsTimeline = [];
	$.each(timeline, function(index, tweet){
	    //console.log(tweet.text);
	    $.each(self.neighbors, function(index, neighbor){
		if(neighbor == tweet.user.id_str){
		    neighborsTimeline.push(tweet);
		}
	    });
	});
	if(merge == true){
	    $.merge(neighborsTimeline, self.neighborsTimeline);
	    self.neighborsTimeline = neighborsTimeline;
	}
	else
	    self.neighborsTimeline = neighborsTimeline;
    }
};

window.maptter.route({
    path: "/",
    func: function(){
	var maptter = window.maptter;
	$(document).ready(function(){
	    maptter.initFriendsMap();
	    setInterval(maptter.getTimeline, 60000);
	});
    }
});
