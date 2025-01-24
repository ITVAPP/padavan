<!DOCTYPE html>
<html>
<head>
   <title><#Web_Title#> - 屏蔽名单</title>
   <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
   <meta http-equiv="Pragma" content="no-cache">
   <meta http-equiv="Expires" content="-1">

   <link rel="shortcut icon" href="images/favicon.ico">
   <link rel="icon" href="images/favicon.png">
   <link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
   <link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">
   <link rel="stylesheet" type="text/css" href="/bootstrap/css/engage.itoggle.css">

   <script type="text/javascript" src="/jquery.js"></script>
   <script type="text/javascript" src="/bootstrap/js/bootstrap.min.js"></script>
   <script type="text/javascript" src="/bootstrap/js/engage.itoggle.min.js"></script>
   <script type="text/javascript" src="/state.js"></script>
   <script type="text/javascript" src="/general.js"></script>
   <script type="text/javascript" src="/itoggle.js"></script>
   <script type="text/javascript" src="/popup.js"></script>
   <script type="text/javascript" src="/help.js"></script>

   <script>
       var $j = jQuery.noConflict();

       function processLogContent(content) {
           if (!content || content.trim() === "") return "暂无屏蔽名单数据";
           
           try {
               var logs = content.split("***************************************");
               var latestIPv4Block = null;
               
               // 从后向前查找最新的 IPv4 黑名单
               for (var i = logs.length - 1; i >= 0; i--) {
                   var block = logs[i].trim();
                   if (block.includes("IPv4 黑名单：")) {
                       latestIPv4Block = block;
                       break;
                   }
               }
               
               return latestIPv4Block || "暂无 IPv4 黑名单数据";
           } catch(e) {
               console.error('处理日志错误:', e);
               return "处理日志时发生错误";
           }
       }

       function initial() {
           try {
               show_banner(2);
               show_menu(5, 4, 6);
               show_footer();
               
               var rawContent = E('textarea_raw');
               if (rawContent) {
                   E('textarea').value = processLogContent(rawContent.value);
               }
           } catch(e) {
               console.error('初始化错误:', e);
           }
       }
   </script>
</head>

<body onload="initial();" onunLoad="return unload_body();">
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
       <textarea id="textarea_raw" style="display:none"><% nvram_dump("IPblacklist-log.txt",""); %></textarea>

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
                               <h2 class="box_head round_top">IP屏蔽名单</h2>
                               <div class="round_bottom">
                                   <div class="row-fluid">
                                       <div id="tabMenu" class="submenuBlock"></div>
                                       <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                           <tr>
                                               <td style="border-top: 0 none; padding-bottom: 0px;">
                                                   <textarea rows="21" class="span12" style="height:377px; font-family:'Courier New', Courier, mono; font-size:13px;"
                                                       readonly="readonly" wrap="off" id="textarea"></textarea>
                                               </td>
                                           </tr>
                                           <tr>
                                               <td style="text-align: left; padding-bottom: 0px;">
                                                   <input type="button" onClick="location.href=location.href" value="<#CTL_refresh#>" class="btn btn-primary">
                                                   <input type="button" onClick="location.href='IPblacklist-log.txt'" value="<#CTL_onlysave#>" class="btn btn-success">
                                               </td>
                                           </tr>
                                       </table>
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
