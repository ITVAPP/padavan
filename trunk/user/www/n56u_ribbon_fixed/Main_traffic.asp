<!DOCTYPE html>
<html>
<head>
   <title><#Web_Title#> - Traffic Statistics</title>
   <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
   <meta http-equiv="Pragma" content="no-cache">
   <meta http-equiv="Expires" content="-1">

   <link rel="shortcut icon" href="images/favicon.ico">
   <link rel="icon" href="images/favicon.png">
   <link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
   <link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">

   <script type="text/javascript" src="/jquery.js"></script>
   <script type="text/javascript" src="/bootstrap/js/bootstrap.min.js"></script>
   <script type="text/javascript" src="/state.js"></script>
   <script type="text/javascript" src="/popup.js"></script>
   <script>
       var $j = jQuery.noConflict();

       $j(document).ready(function(){
           $j("#tabs a").click(function(){
               switchPage(this.id);
               return false;
           });
       });
       
       function initial(){
           show_banner(0);
           show_menu(5, -1, 0);
           show_footer();
           loadTrafficStats();
       }
       
       function loadTrafficStats() {
           try {
               var trafficData = <% nvram_dump("traffic_stats.json",""); %>;
               const data = JSON.parse(trafficData);
               
               if (!data || !data.devices || !data.total) {
                   throw new Error('流量统计数据格式不正确或数据为空，如刚重启设备，需等待五分钟后才有数据');
               }

               var grid = '<table class="table table-striped">';
               grid += '<tr><th>IP</th><th>MAC</th><th style="text-align:right">上行</th><th style="text-align:right">下行</th></tr>';

               data.devices.forEach(function (device) {
                   grid += '<tr>';
                   grid += '<td>' + device.ip + '</td>';
                   grid += '<td>' + device.mac + '</td>';
                   grid += '<td style="text-align:right">' + device.up_formatted + '</td>';
                   grid += '<td style="text-align:right">' + device.down_formatted + '</td>';
                   grid += '</tr>';
               });

               grid += '<tr style="font-weight:bold">';
               grid += '<td colspan="2">Total</td>';
               grid += '<td style="text-align:right">' + data.total.up_formatted + '</td>';
               grid += '<td style="text-align:right">' + data.total.down_formatted + '</td>';
               grid += '</tr>';
               grid += '</table>';

               document.getElementById('traffic-grid').innerHTML = grid;
               document.getElementById('update_time').innerHTML = '最后更新: ' + data.time;
           } catch(error) {
               document.getElementById('traffic-grid').innerHTML = '<div class="alert alert-danger">加载失败：' + error.message + '</div>';
               document.getElementById('update_time').innerHTML = '';
           }
       }

       function switchPage(id) {
           if (id == "tab_bw_rt")
               location.href = "/Main_TrafficMonitor.asp";
           else if (id == "tab_tr_traffic")
               location.href = "/Main_traffic.asp";
           else if (id == "tab_bw_24")
               location.href = "/Main_TrafficMonitor_last24.asp";
           else if (id == "tab_tr_dy")
               location.href = "/Main_TrafficMonitor_daily.asp#DY";
           else if (id == "tab_tr_mo")
               location.href = "/Main_TrafficMonitor_daily.asp#MO";
           return false;
       }
   </script>
   <style>
       #tabs {margin-bottom: 0px;}
   </style>
</head>

<body onload="initial();">
<!--Body content-->
<div class="wrapper">
   <div class="container-fluid" style="padding-right: 0px">
       <div class="row-fluid">
           <div class="span3"><center><div id="logo"></div></center></div>
           <div class="span9">
               <div id="TopBanner"></div>
           </div>
       </div>
   </div>

   <div id="Loading" class="popup_bg"></div>

   <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>

   <div class="container-fluid">
       <div class="row-fluid">
           <div class="span3">
               <!--=====Beginning of Main Menu=====-->
               <div class="well sidebar-nav side_nav" style="padding: 0px;">
                   <ul id="mainMenu" class="clearfix"></ul>
                   <ul class="clearfix">
                       <li>
                           <div id="subMenu" class="accordion"></div>
                       </li>
                   </ul>
               </div>
           </div>

           <div class="span9">
               <!--Body content-->
               <div class="row-fluid">
                   <div class="span12">
                       <div class="box well grad_colour_dark_blue">
                           <h2 class="box_head round_top">Traffic Statistics</h2>
                           <div class="round_bottom">
                             <div id="tabMenu" class="submenuBlock"></div>
                               <div style="margin-bottom: 0px; margin: -36px 0px 0px 0px;">
                                   <ul id="tabs" class="nav nav-tabs">
                                       <li><a href="javascript:void(0)" id="tab_bw_rt"><#menu4_2_1#></a></li>
                                       <li class="active"><a href="javascript:void(0)" id="tab_tr_traffic">设备流量统计</a></li>
                                       <li><a href="javascript:void(0)" id="tab_bw_24"><#menu4_2_2#></a></li>
                                       <li><a href="javascript:void(0)" id="tab_tr_dy"><#menu4_2_3#></a></li>
                                       <li><a href="javascript:void(0)" id="tab_tr_mo"><#menu4_2_4#></a></li>
                                   </ul>
                               </div>

                               <div class="row-fluid">
                                   <div class="alert alert-info" style="margin: 10px;">
                                       本流量统计非实时统计，每五分钟更新一次
                                   </div>
                                   <div id="traffic-grid"></div>
                                   <div id="update_time" style="text-align:right;padding:5px;"></div>
                                   <button onclick="loadTrafficStats()" class="btn btn-primary">刷新</button>
                               </div>
                           </div>
                       </div>
                   </div>
               </div>
           </div>
       </div>
   </div>
   <div id="footer"></div>
</div>
</body>
</html>
