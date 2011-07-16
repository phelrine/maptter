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
	    .data("id", data.user_id)
	    .attr({
		src: data.image_url,
		alt: data.screen_name,
		title: data.screen_name,
	    })
	    .css({
		top: data.pos.x,
		left: data.pos.y
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
	    $(".map").append(
		Map.makeDraggableIcon({
		    user_id: 0,
		    screen_name: "icon",
		    pos: {x: 16, y: 16},
		    image_url: "none"
		})
	    );
	});
    }
});
