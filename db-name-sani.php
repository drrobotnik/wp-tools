#!/usr/bin/php -q
<?php $argv;
if( count($argv) < 1 )
	return false;

$input = $argv[1];


$alpha_num_dashes = preg_replace('/[^a-zA-Z0-9\-]/', '', $input); // replace everything but alpha numerics and dashes.
$db_name = preg_replace_callback('/[^a-zA-Z]/', 'replace_num', $alpha_num_dashes);


function create_slug($input){
	$slug = preg_replace('/[^A-Z]/', '', $input); // replace everything but alpha numerics and dashes.
	return strtolower($slug);
}

function replace_num($match){
	$num = array('Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine','-'=>'_');
	return $num[$match[0]];
}

echo create_slug($db_name); exit();