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

window.maptter.route({
    path: "/",
    func: function(){
    }
});
