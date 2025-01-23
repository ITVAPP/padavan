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
       function loadTrafficStats() {
           // 使用 Fetch API 从 /www/traffic_stats.json 文件加载数据
           fetch('/traffic_stats.json')
               .then(response => {
                   if (!response.ok) {
                       throw new Error('无法加载流量统计文件');
                   }
                   return response.json(); // 解析 JSON 数据
               })
               .then(data => {
                   // 检查数据有效性
                   if (!data || !data.devices || !data.total) {
                       throw new Error('流量统计数据格式不正确或数据为空');
                   }

                   // 动态生成流量统计表格
                   var grid = '<table class="table table-striped">';
                   grid += '<tr><th>IP</th><th>MAC</th><th style="text-align:right">上行</th><th style="text-align:right">下行</th></tr>';
                   
                   data.devices.forEach(function(device) {
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

                   // 更新表格内容到页面
                   document.getElementById('traffic-grid').innerHTML = grid;
                   document.getElementById('update_time').innerHTML = '最后更新: ' + data.time;
               })
               .catch(error => {
                   // 如果加载失败或数据无效，显示错误信息
                   document.getElementById('traffic-grid').innerHTML = '<div class="alert alert-danger">加载失败：' + error.message + '</div>';
                   document.getElementById('update_time').innerHTML = '';
               });
       }

       // 页面加载时自动加载流量统计数据
       document.addEventListener('DOMContentLoaded', loadTrafficStats);
   </script>
</head>

<body>
<div class="wrapper">
   <div class="container-fluid" style="padding-right: 0px">
       <div class="row-fluid">
           <div class="span3"><center><div id="logo"></div></center></div>
           <div class="span9"><div id="TopBanner"></div></div>
       </div>
   </div>

   <div class="container-fluid">
       <div class="row-fluid">
           <div class="span3">
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
               <div class="row-fluid">
                   <div class="span12">
                       <div class="box well grad_colour_dark_blue">
                           <h2 class="box_head round_top">Traffic Statistics</h2>
                           <div class="round_bottom">
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
