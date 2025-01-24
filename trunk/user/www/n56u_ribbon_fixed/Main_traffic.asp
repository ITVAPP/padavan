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
           try {
               show_banner(0);
               show_menu(5, -1, 0);
               show_footer();
           } catch(e) {
               console.error('Layout initialization error:', e);
           }
           
           try {
               loadTrafficStats();
           } catch(e) {
               console.error('Traffic stats loading error:', e);
           }
       }
       
       function loadTrafficStats() {
           try {
               // 获取数据，需要处理空值情况
               var trafficData = <% nvram_dump("traffic_stats.json",""); %>;
               
               // 检查 trafficData 是否为空或未定义
               if (!trafficData) {
                   throw new Error('未找到流量统计数据文件');
               }

               // 尝试解析 JSON
               let data = trafficData;
               if (typeof trafficData === 'string') {
                   try {
                       data = JSON.parse(trafficData);
                   } catch (parseError) {
                       throw new Error('流量统计数据格式不正确');
                   }
               }
               
               // 验证数据结构
               if (!data || !Array.isArray(data.devices) || !data.total || !data.time) {
                   throw new Error('流量统计数据结构不完整');
               }

               // 构建表格
               var grid = '<table class="table table-striped">';
               grid += '<tr><th>IP</th><th>MAC</th><th style="text-align:right">上行</th><th style="text-align:right">下行</th></tr>';

               // 设备数据
               if (data.devices.length === 0) {
                   grid += '<tr><td colspan="4" style="text-align:center">暂无设备流量数据</td></tr>';
               } else {
                   data.devices.forEach(function (device) {
                       grid += '<tr>';
                       grid += '<td>' + (device.ip || '-') + '</td>';
                       grid += '<td>' + (device.mac || '-') + '</td>';
                       grid += '<td style="text-align:right">' + (device.up_formatted || '0 B') + '</td>';
                       grid += '<td style="text-align:right">' + (device.down_formatted || '0 B') + '</td>';
                       grid += '</tr>';
                   });
               }

               // 总计行
               grid += '<tr style="font-weight:bold">';
               grid += '<td colspan="2">Total</td>';
               grid += '<td style="text-align:right">' + (data.total.up_formatted || '0 B') + '</td>';
               grid += '<td style="text-align:right">' + (data.total.down_formatted || '0 B') + '</td>';
               grid += '</tr>';
               grid += '</table>';

               // 更新 DOM
               document.getElementById('traffic-grid').innerHTML = grid;
               document.getElementById('update_time').innerHTML = '最后更新: ' + (data.time || new Date().toLocaleString());

           } catch(error) {
               // 错误提示使用更友好的方式显示
               var errorMessage = '加载失败：' + error.message;
               if (error.message.includes('未找到')) {
                   errorMessage += '<br>可能原因：<ul style="margin-top:10px">' +
                       '<li>设备刚重启，需要等待约5分钟才会开始统计</li>' +
                       '<li>统计功能可能未正确开启</li>' +
                       '<li>统计数据文件可能损坏</li></ul>';
               }
               
               document.getElementById('traffic-grid').innerHTML = 
                   '<div class="alert alert-danger" style="margin:10px">' + errorMessage + '</div>';
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
