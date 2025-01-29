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
           if (!content || content.trim() === "") {
               return "暂无屏蔽名单数据";
           }
           
           try {
               // 将内容按分隔符分割成块
               const blocks = content.split('***************************************');
               
               // 查找最后一个包含 "IPv4 黑名单：" 的有效块
               let lastValidBlock = null;
               for (let i = blocks.length - 1; i >= 0; i--) {
                   const block = blocks[i].trim();
                   if (block.includes('IPv4 黑名单：')) {
                       lastValidBlock = block;
                       break;
                   }
               }
               
               if (!lastValidBlock) {
                   return "暂无屏蔽名单数据";
               }
               
               // 提取时间戳和黑名单内容
               const timestampMatch = lastValidBlock.match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [A-Z]{3,4}/);
               const timestamp = timestampMatch ? timestampMatch[0] : "";
               
               // 获取 "IPv4 黑名单：" 之后的所有内容
               const blacklistContent = lastValidBlock.split('IPv4 黑名单：')[1].trim();
               
               return `${timestamp} IPv4 黑名单：\n${blacklistContent}`;
               
           } catch(e) {
               console.error('处理日志错误:', e);
               return "处理日志时发生错误";
           }
       }

       function initial() {
           try {
               show_banner(1);
               show_menu(5, 5, 6);
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
                                       <div class="alert alert-info" style="margin: 10px;">屏蔽尝试连接本设备 20,21,22,23,3389 端口的IP<br>
使用本功能需在 系统管理 - 服务 - 调度任务 (Crontab) 中取消 flytrap 前的 # 号注释</div>
                                       <table width="100%" cellpadding="4" cellspacing="0" class="table">
                                           <tr>
                                               <td style="border-top: 0 none; padding-bottom: 0px;">
                                                   <textarea rows="21" class="span12" style="height:377px; font-family:'Courier New', Courier, mono; font-size:13px;"
                                                       readonly="readonly" wrap="off" id="textarea"></textarea>
                                               </td>
                                           </tr>
                                       </table>
                                       <table class="table">
                                        <tbody><tr>
                                            <td style="border: 0 none;"><center><input type="button" onClick="location.href=location.href" value="<#CTL_refresh#>" class="btn btn-primary" style="width: 219px"></center></td>
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
