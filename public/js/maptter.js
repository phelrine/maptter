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
	    .data({id: data.id, user_id: data.user_id})
	    .attr({
		src: data.profile_image_url_https,
		alt: data.screen_name,
		title: data.screen_name,
	    })
	    .css({
		top: data.top,
		left: data.left
	    })
	    .draggable({
		stop: function(e, ui){
		    console.log(ui.position);
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
