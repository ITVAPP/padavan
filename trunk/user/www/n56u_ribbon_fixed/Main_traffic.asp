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
   var sortDirection = {up: false, down: false}; // false 为升序，true 为降序
   var currentPage = 1;
   var itemsPerPage = 18;

   window.initial = function(){
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
   };

   $j(document).ready(function(){
       $j("#tabs a").click(function(){
           switchPage(this.id);
           return false;
       });
   });

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
   
   function renderGrid(data) {
       var grid = '<table class="table table-striped">';
       grid += '<tr><th width="20%">IP</th><th width="25%">主机名</th><th>MAC</th>' +
               '<th width="15%" style="text-align:right;cursor:pointer" onclick="sortDevices(\'up\')">上行 ▼</th>' +
               '<th width="15%" style="text-align:right;cursor:pointer" onclick="sortDevices(\'down\')">下行 ▼</th></tr>';

       if (data.devices.length === 0) {
           grid += '<tr><td colspan="5" style="text-align:center">暂无设备流量数据</td></tr>';
       } else {
           // 计算当前页的数据范围
           var start = (currentPage - 1) * itemsPerPage;
           var end = Math.min(start + itemsPerPage, data.devices.length);
           
           // 只渲染当前页的数据
           for (var i = start; i < end; i++) {
               var device = data.devices[i];
               if (!device?.ip || !device?.mac) {
                   console.warn('设备数据不完整:', device);
                   continue;
               }
               grid += '<tr>';
               grid += '<td>' + (device.ip || '-') + '</td>';
               grid += '<td>' + (device.hostname || '-') + '</td>';
               grid += '<td>' + (device.mac || '-') + '</td>';
               grid += '<td style="text-align:right">' + (device.up_formatted || '0 B') + '</td>';
               grid += '<td style="text-align:right">' + (device.down_formatted || '0 B') + '</td>';
               grid += '</tr>';
           }
       }

       grid += '<tr style="font-weight:bold">';
       grid += '<td colspan="3">Total</td>';
       grid += '<td style="text-align:right">' + (data.total.up_formatted || '0 B') + '</td>';
       grid += '<td style="text-align:right">' + (data.total.down_formatted || '0 B') + '</td>';
       grid += '</tr>';
       grid += '</table>';

       // 添加分页控件
       if (data.devices.length > itemsPerPage) {
           var totalPages = Math.ceil(data.devices.length / itemsPerPage);
           grid += '<div class="pagination" style="text-align:center"><ul>';
           
           // 上一页按钮
           grid += '<li' + (currentPage === 1 ? ' class="disabled"' : '') + '>';
           grid += '<a href="javascript:void(0)" onclick="' + (currentPage === 1 ? 'return false' : 'changePage(' + (currentPage - 1) + ')') + '">&laquo;</a></li>';
           
           // 页码按钮
           for (var i = 1; i <= totalPages; i++) {
               grid += '<li' + (i === currentPage ? ' class="active"' : '') + '>';
               grid += '<a href="javascript:void(0)" onclick="changePage(' + i + ')">' + i + '</a></li>';
           }
           
           // 下一页按钮
           grid += '<li' + (currentPage === totalPages ? ' class="disabled"' : '') + '>';
           grid += '<a href="javascript:void(0)" onclick="' + (currentPage === totalPages ? 'return false' : 'changePage(' + (currentPage + 1) + ')') + '">&raquo;</a></li>';
           
           grid += '</ul></div>';
       }

       document.getElementById('traffic-grid').innerHTML = grid;
       updateSortIndicators(Object.keys(sortDirection).find(key => sortDirection[key]) || '');
   }

   function changePage(page) {
       currentPage = page;
       renderGrid(window.trafficStatsData);
   }

   function sortDevices(type) {
       // 切换当前列的排序方向
       sortDirection[type] = !sortDirection[type];
       
       // 重置其他列的排序方向
       for (let key in sortDirection) {
           if (key !== type) {
               sortDirection[key] = false;
           }
       }
       
       // 排序数据
       window.trafficStatsData.devices.sort((a, b) => {
           let aValue = parseInt(a[type + '_bytes']) || 0;
           let bValue = parseInt(b[type + '_bytes']) || 0;
           return sortDirection[type] ? bValue - aValue : aValue - bValue;
       });
       
       // 排序后重置为第一页
       currentPage = 1;
       renderGrid(window.trafficStatsData);
   }

   function updateSortIndicators(activeType) {
       const upHeader = document.querySelector('th[onclick="sortDevices(\'up\')"]');
       const downHeader = document.querySelector('th[onclick="sortDevices(\'down\')"]');
       
       upHeader.innerHTML = '上行 ' + (activeType === 'up' ? (sortDirection.up ? '▼' : '▲') : '▼');
       downHeader.innerHTML = '下行 ' + (activeType === 'down' ? (sortDirection.down ? '▼' : '▲') : '▼');
   }
   
function loadTrafficStats() {
    try {
        var trafficData = "<% nvram_dump("traffic_stats.json",""); %>";
        // 先用临时变量解析，避免直接赋值给全局变量时的错误
        const data = typeof trafficData === 'object' ? trafficData : JSON.parse(trafficData);
        window.trafficStatsData = data;
        
        if (window.trafficStatsData === null || window.trafficStatsData === "null" || window.trafficStatsData === "" || Object.keys(window.trafficStatsData).length < 3) {
            document.getElementById('traffic-grid').innerHTML = 
                '<div class="alert alert-danger" style="margin:10px">未找到有效的流量统计数据<br>' +
                '可能原因：<ul style="margin-top:10px">' +
                '<li>设备刚重启，需要等待约5分钟才会开始统计</li>' +
                '<li>统计功能可能未正确开启</li>' +
                '<li>统计数据文件可能损坏</li></ul></div>';
            document.getElementById('update_time').innerHTML = '';
            return;
        }
        
        if (!window.trafficStatsData?.time || !Array.isArray(window.trafficStatsData?.devices) || !window.trafficStatsData?.total?.up_formatted || !window.trafficStatsData?.total?.down_formatted) {
            throw new Error('暂无流量统计数据');
        }

        renderGrid(window.trafficStatsData);
        document.getElementById('update_time').innerHTML = '最后更新: ' + (window.trafficStatsData.time || new Date().toLocaleString());

    } catch(error) {
        console.error('Traffic stats error:', error);
        var errorMessage = '加载失败：' + error.message;
        if (error.message.includes('格式不正确') || error.message.includes('数据结构不完整')) {
            errorMessage += '<br>请检查数据文件格式是否符合要求';
        }
        
        document.getElementById('traffic-grid').innerHTML = 
            '<div class="alert alert-danger" style="margin:10px">' + errorMessage + '</div>';
        document.getElementById('update_time').innerHTML = '';
    }
}
</script>
<style>
   #tabs {
       margin-bottom: 0px;
   }
   /* Fix tabMenu position */
   #tabMenu {
       margin: 10px 0;
       width: 100%;
       clear: both;
       display: block;
   }
</style>
</head>

<body onload="window.initial && window.initial();">
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
                       <h2 class="box_head round_top">流量统计数据</h2>
                       <div class="round_bottom">
                           <div class="row-fluid">
                               <!-- Moved tabMenu to its own line -->
                               <div id="tabMenu" class="submenuBlock"></div>
                               
                               <div>
                                   <ul id="tabs" class="nav nav-tabs">
                                       <li><a href="javascript:void(0)" id="tab_bw_rt"><#menu4_2_1#></a></li>
                                       <li class="active"><a href="javascript:void(0)" id="tab_tr_traffic">设备流量统计</a></li>
                                       <li><a href="javascript:void(0)" id="tab_bw_24"><#menu4_2_2#></a></li>
                                       <li><a href="javascript:void(0)" id="tab_tr_dy"><#menu4_2_3#></a></li>
                                       <li><a href="javascript:void(0)" id="tab_tr_mo"><#menu4_2_4#></a></li>
                                   </ul>
                               </div>
                               
                               <div class="alert alert-info" style="margin: 10px;">
                                   本流量统计非实时统计，每五分钟更新一次<br>使用本功能需在 系统管理 - 服务 - 调度任务 (Crontab) 中取消 traffic 前的 # 号注释
                               </div>
                               <div id="update_time" style="text-align:right;padding:5px;"></div>
                               <div id="traffic-grid"></div>
                                    <table class="table">
                                       <tbody><tr>
                                           <td style="border: 0 none;"><center><button onclick="window.location.reload()" class="btn btn-primary" style="width: 219px">刷新</button></center></td>
                                       </tr>
                                   </tbody></table>
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
