if(!window.maptter) window.maptter = {};

window.maptter.route = function() {
    var pathname = location.pathname;
    $.each(arguments, function(key){
	var path = this.path;
	var func = this.func;
	
	if(!path || !func) return;
	if(pathname === path || (path.test && path.test(pathname)))
	    func();
    });
};

window.maptter.Map = {
    makeDraggableIcon : function(data){
	return $("<img>").addClass("icon")
	    .data({friend_id: data.friend_id})
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
			console.log(data);
		    });
		},
		containment: "parent"
	    });
    }
};

window.maptter.route({
    path: "/",
    func: function(){
	var Map = window.maptter.Map;
	$(document).ready(function(){
	    $.get("/map/friends", "", function(data, status){
		$.each(data, function(index, value){
		    $(".map").append(
			Map.makeDraggableIcon(
			    value
			)
		    );
		});

	    });
	});
    }
});
