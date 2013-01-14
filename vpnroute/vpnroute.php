<?php

function getNetRange() {
  // Create a stream
  $postdata = http_build_query(
      array('COUNTRY' => 'CN','FORMAT' => '1',)
  );

  $opts = array(
    'http'=>array(
      'method'=>"POST",
      'header'=>
      	"Accept-language: en\r\n".
      	"Content-type: "."application/x-www-form-urlencoded"."\r\n",
      'content'=>$postdata
    )
  );

  $context = stream_context_create($opts);

  // Open the file using the HTTP headers set above
  $file = file_get_contents('http://software77.net/geo-ip/', false, $context);

  // Find "<textarea>...</textarea>"
  $begin = strpos($file, "<textarea");
  $end = strpos($file, "</textarea>");

  // Parse IP list
  $pattern_ip = '/(\d+\.\d+\.\d+\.\d+\/\d+)/';
  if ($begin !== false && $end !== false) {
  	$text = substr($file, $begin, $end - $begin);
  	preg_match_all($pattern_ip, $text, $matches);
    return $matches[1];
  }
}

$cache_file = 'file/net.txt';
$cache_interval = 24 * 60 * 60;
$content = "";
if(!file_exists($cache_file) || filemtime($cache_file) + $cache_interval < time()) {
  //echo "# From Web \n";
  $net_list = getNetRange();
  foreach ($net_list as $net) {
    $content .= $net . "\n";
  }
  file_put_contents($cache_file, $content);
}else{
  //echo "# From Cache \n";
  $content = file_get_contents($cache_file);
}

echo $content;

?>