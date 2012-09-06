module.exports = (robot) ->
	io = require('socket.io').listen robot.server
	io.set 'log level', 0
	robot.brain.data.stats = {}

	io.sockets.on 'connection', (socket) ->
		socket.emit 'statsdata', robot.brain.data.stats

	robot.hear '.*', (msg) ->
		room = msg.message.user.room
		user = msg.message.user.name
		user = robot.usersForFuzzyName(user)
		if user.length is 1
			user = user[0].name
		else
			user = msg.message.user.name
		d = new Date()
		d = (new Date(d.getFullYear(), d.getMonth(), d.getDate(), d.getHours(), d.getMinutes())).valueOf()
		robot.brain.data.stats[d] ?= {}
		robot.brain.data.stats[d]['rooms'] ?= {}
		robot.brain.data.stats[d]['users'] ?= {}
		robot.brain.data.stats[d]['rooms'][room] ?= 0
		robot.brain.data.stats[d]['rooms'][room] += 1
		robot.brain.data.stats[d]['users'][user] ?= 0
		robot.brain.data.stats[d]['users'][user] += 1
		senddata = {}
		senddata[d] = robot.brain.data.stats[d]
		io.sockets.emit 'statsdata', senddata

	robot.router.get '/hubot/stats', (req,res) ->
		res.end """
		<html>
		<head>
		<script type="text/javascript" src="/socket.io/socket.io.js"></script>
		<script type="text/javascript" src="http://d3js.org/d3.v2.min.js?2.10.1"></script>
		</head>
		<body>
		Rooms: <select id="rooms"></select> Users: <select id="users"></select>
		<div id="chart"></div>

		<script type="text/javascript">
		var width = 800;
		var height = 550;
		var margin = 20;
		var scalefactor = 60*1000;
		var roomsmenu = d3.select("#rooms").on('change', function() { d3.select('#users').property('value',''); redraw(); });
		var usersmenu = d3.select("#users").on('change', function() { d3.select('#rooms').property('value',''); redraw(); });
		var chart = d3.select('body').append('svg').attr('width',width).attr('height',height);
		var data = {};
		var socket = io.connect();
		socket.on('statsdata', function(data_in) {
			for(var k in data_in) {
				data[k] = data_in[k];
			}
			redraw();
		});

		function userMenu() {
			var menuData = d3.merge(["",d3.merge(d3.keys(data).map(function(d) { return d3.keys(data[d].users); }))]);
			var um = usersmenu.selectAll('option').data(menuData);
			um.enter().append('option').text(function(d) { return d; });
			um.exit().remove();
		}

		function roomMenu() {
			var menuData = d3.merge(["",d3.merge(d3.keys(data).map(function(d) { return d3.keys(data[d].rooms); }))]);
			var rm = roomsmenu.selectAll('option').data(menuData);
			rm.enter().append('option').text(function(d) { return d; });
			rm.exit().remove();
		}

		function drawChart(data_in) {
			var chartD = chart.selectAll('rect').data(data_in,function(d) { return d.time;});
			var mintime = d3.min(data_in, function(d) { return d.time; });
			var maxtime = d3.max(data_in, function(d) { return d.time; });
			var mincount = 0;
			var maxcount = d3.max(data_in, function(d) { return d.count; });
			//function scaleTime(d) { 
			//if(maxtime==mintime) { return width; }
			//	else { return width/(((maxtime+scalefactor)-mintime)/scalefactor); }
			//}
			function scaleTime(d) { return 5; }
			var x = d3.scale.linear().domain([mintime,maxtime]).range([0+margin,width-margin]);
			var y = d3.scale.linear().domain([mincount,maxcount]).range([0+margin,height-margin]);
			var r = d3.scale.linear().domain([mincount,maxcount]).range([0+margin,height-margin]);

			chartD.enter().append('rect').attr('height',function(d) { return y(d.count); }).attr('width',scaleTime).attr('x',function(d){return x(d.time);}).attr('y',function(d){return (height-margin)-y(d.count);}).attr('fill','rgb(0,0,255)');
			chartD.transition().duration(100).attr('height',function(d) { return y(d.count); }).attr('width',scaleTime).attr('x',function(d){return x(d.time);}).attr('y',function(d){return (height-margin)-y(d.count);});
			chartD.exit().remove();

			var yRules = chart.selectAll(".yrule").data(r.ticks(Math.ceil(maxcount/10)));
   			yRules.enter().append("text").attr("class", "yrule").attr("x", 0).attr("y", function(d) { return height-r(d);})
     		.attr("dx", margin/2)
     		.attr("text-anchor", "middle")
     		.text(String);
     		yRules.attr("y", function(d) { return height-r(d);});
     		yRules.exit().remove();

     		var xRules = chart.selectAll(".xrule").data(x.ticks(Math.min(15,Math.ceil((maxtime-mintime)/60000))));
   			xRules.enter().append("text").attr("class", "xrule").attr("x", x).attr("y", height)
     		.attr("dy", -1*margin/2)
     		.attr("text-anchor", "middle")
     		.text(function(d) { var dt = new Date(d); return dt.getHours() +":" + dt.getMinutes();});
     		xRules.attr("x", x);
     		xRules.exit().remove();
		}

		function drawUserChart(filter) {
			var filterData = sort_unique(d3.keys(data).filter(function(d) { return data[d].users[filter] != undefined; }).map(function(d) { return { time:d, count:data[d].users[filter]}; }));
			drawChart(filterData);
		}

		function drawRoomChart(filter) {
			var filterData = sort_unique(d3.keys(data).filter(function(d) { return data[d].rooms[filter] != undefined; }).map(function(d) { return { time:d, count:data[d].rooms[filter]}; }));
			drawChart(filterData);
		}

		//thank you stackoverflow
		function sort_unique(arr) {
		    arr = arr.sort();
		    var ret = [arr[0]];
		    for (var i = 1; i < arr.length; i++) { // start loop at 1 as element 0 can never be a duplicate
		        if (arr[i-1] !== arr[i]) {
		            ret.push(arr[i]);
		        }
		    }
		    return ret;
		}

		function redraw() {
			userMenu();
			roomMenu();
			if(roomsmenu.property('value') != '') {
				drawRoomChart(roomsmenu.property('value'));
			} else if(usersmenu.property('value') != ''){
				drawUserChart(usersmenu.property('value'));
			}
		}
		</script>
		</body>
		"""