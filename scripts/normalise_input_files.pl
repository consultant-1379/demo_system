#!/usr/bin/perl


# ********************************************************************
#
# 	Imports
#
# ********************************************************************
#

use warnings;
use POSIX qw/strftime/;
use Time::Local;
use File::Copy;
use File::Path;
use File::Find;
use File::Spec;
use File::Basename;

 
# ********************************************************************
#
# 	Main body of program
#
# ********************************************************************
#


#
# 	Setting up variables/arrays
#

$err_msg="";
$error_number=0;
$OffsetTime="";
%commonDays=('0'=>'0');
@node_dirs = ();
@rop_names=();
@rop=();
$loop_node_name="node_name_empty";

#
# 	Confirming that the correct arguments used with script
#
checkArguments(@ARGV);


#
# 	Reading  arguments and creating output and input paths
#
my ($inputDirectory_temp, $outputDirectory_temp, $logStatus, $moveStatus, $norm) = @ARGV;


my $inputDirectory_path = File::Spec->rel2abs( $inputDirectory_temp) ;
my $outputDirectory_path = File::Spec->rel2abs( $outputDirectory_temp) ;

my $inputDirectory= (split(/\//, $inputDirectory_path))[-1];
my $outputDirectory= (split(/\//, $outputDirectory_path))[-1];

$inputDirectory_path =~ s/$inputDirectory//;

$incompatOutputDirectory_path=dirname($outputDirectory_path)."/incompatible/";
mkpath($incompatOutputDirectory_path) unless -d $incompatOutputDirectory_path;

if (index($inputDirectory, "/") != -1) {
    $inputDirectory =~ s/\/+$//;
} 
if (index($outputDirectory, "/") != -1) {
    $outputDirectory =~ s/\/+$//;
} 
if ($moveStatus eq "C") {
	$moveWord=" Copying"
}elsif ($moveStatus eq "M") {
	$moveWord=" Moving"
}elsif ($moveStatus eq "S") {
	$moveWord=" Creating symbolic link for"
}

#
# 	Setting up log file if logging is on
#
my $logFile = "normalise_input_files_".strftime("%Y-%m-%d_%H:%M", localtime).".log";
if($logStatus eq "ON") {
	open LOGFILE, ">>$logFile" or abort_script(strftime("%Y/%m/%d %H:%M:%S", localtime)." ABORT - Unable to create $logFile\n",1001);
}
printToLogFile(strftime("%Y/%m/%d %H:%M:%S", localtime)." Starting to normalise files.\n");
#
#	Checking if output directory is empty and clearing if not
#
checkIfOuputDirectoryIsEmpty($outputDirectory_path);
cleantIncompatibleDirectory($incompatOutputDirectory_path);
#
#	Building array of files to process and incompatible files 
#



my @mss_files = glob($inputDirectory_path."/".$inputDirectory.'/*/*/*.xml.gz');
my @other_files = glob($inputDirectory_path."/".$inputDirectory.'/*/*/*A20*');
my @files = (@mss_files,@other_files);
my @all_files = glob($inputDirectory_path."/".$inputDirectory.'/*/*/*');
my %seen;
@seen {@all_files} = ( );
delete @seen {@files};
my @none_node_files = keys %seen;

#
# 	Cleaning incompatible files to incomplete
#
clean_incompatiable_files(\@none_node_files);




@sortedMssFilesDate =
		sort {

			$date_from_a = $a =~ /\.(\d(12))\+/;
			$date_from_b = $b =~ /\.(\d(12))\+/;
			$date_from_a <=> $date_from_b
		}
		@mss_files;

@sortedMssFiles = sort @sortedMssFilesDate;

@sortedOtherFilesDate =
		sort {
			my ($date_from_a) = $a =~ /\/\w*A(\d{8}\.\d{4})/;
			my ($date_from_b) = $b =~ /\/\w*A(\d{8}\.\d{4})/;
			$date_from_a <=> $date_from_b
		}
		@other_files;

 @sortedOtherFiles = sort @sortedOtherFilesDate;

#
# 	Creating output paths and normalising files.
# 
$day_count=0;  
 foreach my $file (@sortedMssFiles) {
	create_output_file($file);
}

 for (keys %commonDays)
 {
    delete $commonDays{$_};
  }
%commonDays=('0'=>'0');

$day_count=0;  
 foreach my $file (@sortedOtherFiles) {
	create_output_file($file);
}



@unique_node_dirs = uniq(@node_dirs);
$num_of_rops=@rop_names;

#
# 	Creating properties file for each node based on name and type
#
 foreach my $node_dir (@unique_node_dirs) {
	createPropertiesFile($node_dir);

}

printToLogFile(strftime("%Y/%m/%d %H:%M:%S", localtime)." Normalising process complete.\n");
# ********************************************************************
#
# subs
#
# ********************************************************************
#


sub clean_incompatiable_files{
 my @none_node_files = @{$_[0]};
 
foreach my $copy_from_file (@none_node_files) {
	if ( $copy_from_file eq '') {
	last;
	}
	printToLogFile(strftime("%Y/%m/%d %H:%M:%S", localtime)." Moving incompatible files to $outputDirectory/incompatible.\n");
	my $copy_to_filename=(split(/\//, $copy_from_file))[-1];
	$incompatOutputDirectory_path=dirname($outputDirectory_path);
	mkpath($incompatOutputDirectory_path."/incompatible/") unless -d $incompatOutputDirectory_path."/incompatible/";
	copy_file_to("$copy_from_file","$incompatOutputDirectory_path/incompatible/$copy_to_filename",1);
	}	

}
##-----------------------------------------------------------------------------------------------------------------------------------##

sub getTime{
	return timelocal(0, substr($_[0], 11, 2), substr($_[0], 9 , 2), substr($_[0], 6, 2), substr($_[0], 4, 2) - 1, substr($_[0], 0, 4));

}
##-----------------------------------------------------------------------------------------------------------------------------------##



sub getTimeMss{
	return timelocal(substr($_[0], 10, 2), substr($_[0], 8, 2), substr($_[0], 6 , 2), substr($_[0], 4, 2), substr($_[0], 2, 2)-1, substr($_[0], 0, 2));
}

##-----------------------------------------------------------------------------------------------------------------------------------##

sub getOffsetMssTime{
	my $zeroTimeDate = timelocal(0, 0, 0, substr($_[0], 4, 2), substr($_[0], 2, 2)-1, substr($_[0], 0, 2));
	return $_[1]-$zeroTimeDate;
}

##-----------------------------------------------------------------------------------------------------------------------------------##

sub getOffsetTime{
	my $zeroTimeDate = timelocal(0, 0, 0, substr($_[0], 6, 2), substr($_[0], 4, 2) - 1, substr($_[0], 0, 4));
	return $_[1]-$zeroTimeDate;
}

##-----------------------------------------------------------------------------------------------------------------------------------##
sub abort_script{
	$err_msg=$_[0];
	$error_number=$_[1];
	
	if ($err_msg eq ""){
		$err_msg="Script aborted.......\n";
		}

	printToLogFile($err_msg); #write output to file and screen function
	exit $error_number;
}
##-----------------------------------------------------------------------------------------------------------------------------------##

sub checkArguments{
	if (@_ != 5 ) {
		die "Usage: normalise_input_files.pl <input_directoty> <output_directoty> <ON|OFF> <C|M|S> <Z|U>
					1. Full directory path to input folder
					2. Full direcotty path to output folder
					3. Whether to create a log or not
					4. Whether to move, copy or create a symbolic link
					5. Whether to normalise to UTC (U) or 00:00:00 UTC (Z)\n"
					
	}
	if (! -d $_[0]) {
		die "Please supply a valid Input directory"
	}
	if (! -d $_[1]) {
		die "Please supply a valid Output directory"
	}
	if (!($_[2] eq "ON" || $_[2] eq "OFF")){
		die "Please select [ON] or [OFF] option for logging."
	}
		if (!($_[3] eq "C" || $_[3] eq "M" || $_[3] eq "S" )){
		die "Please select [C] or [m] or [m] option for how to deal with output file"
	}
		if (!($_[4] eq "Z" || $_[4] eq "U")){
		die "Please select [Z] to normalise to 00:00:00 UTC or [U] to UTC time of file time."
	}

}
##-----------------------------------------------------------------------------------------------------------------------------------##	

sub printToLogFile{
	if ($logStatus eq "ON") {
		my $message = $_[0];
		print $message;
		print LOGFILE $message;
	}
	else{
		my $message = $_[0];
		print $message;
		}
}
##-----------------------------------------------------------------------------------------------------------------------------------##

sub uniq {
  my %seen;
  return grep { !$seen{$_}++ } @_;
}
##-----------------------------------------------------------------------------------------------------------------------------------##

sub checkIfOuputDirectoryIsEmpty{
	my $outputDirectory = $_[0];
	my $containsfiles = 0;

	opendir (OUTPUTDIRECTORY, $outputDirectory ) or abort_script(strftime("%Y/%m/%d %H:%M:%S", localtime)." ABORT - Unable to open $outputDirectory",1002);

	while ( my $file = readdir(OUTPUTDIRECTORY)){
		if ($file =~ m/\w/){
			$containsfiles = 1;
		}
	}

	closedir(OUTPUTDIRECTORY);
	
	if($containsfiles == 1){
		my $notAnswered = 1;
		while($notAnswered == 1){
			printToLogFile(strftime("%Y/%m/%d %H:%M:%S", localtime)." Output directory: ${outputDirectory} contains a local or utc sub-directory, do you want to overwrite them? (yes or no)  ");
			my $answer = <STDIN>;
			chomp $answer;
			if($answer eq "yes"){
				rmtree($outputDirectory);
				mkdir($outputDirectory) or abort_script(strftime("%Y/%m/%d %H:%M:%S", localtime)." ABORT - Unable to recreate $outputDirectory\n",1003);
				printToLogFile(strftime("%Y/%m/%d %H:%M:%S", localtime)." Cleaning output directories.\n");
				$notAnswered = 0;
			}elsif($answer eq "no"){
				printToLogFile(strftime("%Y/%m/%d %H:%M:%S", localtime)." Abort script!!! Didn't want to override local or utc directories. \n");
				if ($logStatus eq "ON") {
					close(LOGFILE);
				}
				die strftime("%Y/%m/%d %H:%M:%S", localtime)." Script Terminated\n";
			}
		}
	}
}

sub cleantIncompatibleDirectory{
	my $outputDirectory = $_[0];
	my $containsfiles = 0;

	opendir (OUTPUTDIRECTORY, $outputDirectory ) or abort_script(strftime("%Y/%m/%d %H:%M:%S", localtime)." ABORT - Unable to open $outputDirectory",1002);

	while ( my $file = readdir(OUTPUTDIRECTORY)){
		if ($file =~ m/\w/){
			$containsfiles = 1;
		}
	}

	closedir(OUTPUTDIRECTORY);
	
	if($containsfiles == 1){
		my $notAnswered = 1;
		while($notAnswered == 1){
			printToLogFile(strftime("%Y/%m/%d %H:%M:%S", localtime)." Incompatiable directory: ${outputDirectory} contains a files, do you want to delete them (NON-RECOVERABLE)? (yes or no)  ");
			my $answer = <STDIN>;
			chomp $answer;
			if($answer eq "yes"){
				rmtree($outputDirectory);
				printToLogFile(strftime("%Y/%m/%d %H:%M:%S", localtime)." Cleaning Incompatiable directory.\n");
				$notAnswered = 0;
			}elsif($answer eq "no"){
				printToLogFile(strftime("%Y/%m/%d %H:%M:%S", localtime)." Incompatiable directory not cleaned. \n");
				$notAnswered = 0;
			}
		}
	}
}
##-----------------------------------------------------------------------------------------------------------------------------------##

sub create_output_file{
	my $file = $_[0];
	my $mssFlag = "NOTMSS";
	$mssFlag = "MSS" if $file =~ m/\.xml\.gz$/;
	$norm = "U" if $mssFlag eq "MSS";
		
	my $file_node_type=(split(/\//, $file))[-3];
	my $file_node_name=(split(/\//, $file))[-2];
	my $file_name=(split(/\//, $file))[-1];
	

	if ( $loop_node_name ne $file_node_name )
	{
		$loop_node_name = $file_node_name;
		$OffsetTime="";
	}
	
	#print "$file_node_type, $file_node_name, $file_name\n";
		
	if ($mssFlag eq "MSS") {
		($StartTime,$tz,$EndTime,$normalise_file_end)=$file_name=~ m/^\S+\.(\d{12})(\+\d{4})\.(\d{12})\+\d{4}(\S+)/;
	}else  {
		($StartTime,$tz,$EndTime,$normalise_file_end)=$file_name=~ m/^\w*A(\d{8}\.\d{4})(\+\d{4})-(\d{8}\.\d{4})\+\d{4}(\S+)/;
	}

	
	
	if(substr($tz, 0, 1) eq "+"){
		if ($mssFlag eq "MSS") {
			$StartTimeEpoch = getTimeMss($StartTime) - ((substr($tz, 1, 2))*60*60 + (substr($tz, 3, 2))*60);
			$EndTimeEpoch = getTimeMss($EndTime) - ((substr($tz, 1, 2))*60*60 + (substr($tz, 3, 2))*60);
		}else  {
			$StartTimeEpoch = getTime($StartTime) - ((substr($tz, 1, 2))*60*60 + (substr($tz, 3, 2))*60);
			$EndTimeEpoch = getTime($EndTime) - ((substr($tz, 1, 2))*60*60 + (substr($tz, 3, 2))*60);
		}
	}else{
		if ($mssFlag eq "MSS") {
			$StartTimeEpoch = getTimeMss($StartTime) + ((substr($tz, 1, 2))*60*60 + (substr($tz, 3, 2))*60);
			$EndTimeEpoch = getTimeMss($EndTime) + ((substr($tz, 1, 2))*60*60 + (substr($tz, 3, 2))*60);
		}else  {
			$StartTimeEpoch = getTime($StartTime) + ((substr($tz, 1, 2))*60*60 + (substr($tz, 3, 2))*60);
			$EndTimeEpoch = getTime($EndTime) + ((substr($tz, 1, 2))*60*60 + (substr($tz, 3, 2))*60);
		}
	}
	
	if ($OffsetTime eq "" && $norm eq "Z") {
		if ($mssFlag eq "MSS") {
			$OffsetTime = getOffsetMssTime($StartTime, $StartTimeEpoch);
		}else  {
			$OffsetTime = getOffsetTime($StartTime, $StartTimeEpoch);
		}
		}
	
	if ($norm eq "Z") {
		 $StartTimeEpoch = $StartTimeEpoch - $OffsetTime;
		 $EndTimeEpoch = $EndTimeEpoch - $OffsetTime;
		}
	
	if ($mssFlag eq "MSS") {
		$NewStartTime = strftime("%y%m%d%H%M%S", localtime($StartTimeEpoch));
		$NewEndTime = strftime("%y%m%d%H%M%S", localtime($EndTimeEpoch));
		#workaround for mms just removing +8000 not adjusting time
		$file_name="$file_node_name.$StartTime+0000.$EndTime+0000$normalise_file_end";
		#$file_name="$file_node_name.$NewStartTime+0000.$NewEndTime+0000$normalise_file_end";
		$rop="MSS";
		$date = (substr($StartTime , 0, 6));
		


	}else  {
		$rop=($EndTimeEpoch-$StartTimeEpoch)/60;
		$date = strftime("%y%m%d", localtime($StartTimeEpoch));
		$NewStartTime = strftime("%Y%m%d.%H%M", localtime($StartTimeEpoch));
		$NewEndTime = strftime("%Y%m%d.%H%M", localtime($EndTimeEpoch));
		$file_name="$file_node_name"."_"."A$NewStartTime+0000-$NewEndTime+0000$normalise_file_end";

		
	}

	
	if( not exists($commonDays{$date} ) ){
		$day_count+=1;
		$commonDays{$date}="$day_count";

		}
	
	push(@rop_names,"$file_node_type/$file_node_name/Day_$commonDays{$date}/$file_name");
	push(@rop,"$rop");
	push(@node_dirs,"$outputDirectory_path/$file_node_type/$file_node_name/");
	

	mkpath($outputDirectory_path.'/'.$file_node_type.'/'.$file_node_name.'/Day_'.$commonDays{$date}.'/') unless -d $outputDirectory_path.'/'.$file_node_type.'/'.$file_node_name.'/Day_'.$commonDays{$date}.'/';
	
	
	if ($mssFlag eq "MSS") {
		printToLogFile(strftime("%Y/%m/%d %H:%M:%S", localtime)."$file to $outputDirectory_path/$file_node_type/$file_node_name/Day_$commonDays{$date}/$file_name\n");
		my $file_out="$outputDirectory_path/$file_node_type/$file_node_name/Day_$commonDays{$date}/$file_name";
		my $output_string="";
		
		# Open input file in read mode
		open ($in, "gzip -dc $file|");
		
			# Open output file in write mode
		open (my $out, "| /bin/gzip -c > $file_out") or die "error starting gzip $!";
		
		while (<$in>) {
		my $insert_line=$_;
		$OLD_YEAR = (substr($StartTime, 0, 2));
		$OLD_MONTH = (substr($StartTime, 2, 2));
		$OLD_DAY = (substr($StartTime, 4, 2));

		$CURRENT_YEAR = (substr($NewStartTime, 0, 2));
		$CURRENT_MONTH = (substr($NewStartTime, 2, 2));
		$CURRENT_DAY = (substr($NewStartTime, 4, 2));

		$StartDate=$OLD_YEAR.$OLD_MONTH.$OLD_DAY;
		$NewStartDate=$CURRENT_YEAR.$CURRENT_MONTH.$CURRENT_DAY;
		$insert_line =~ s/\+08/\+00/g;
		$insert_line =~ s/20${OLD_YEAR}-${OLD_MONTH}-${OLD_DAY}T/20${CURRENT_YEAR}-${CURRENT_MONTH}-${CURRENT_DAY}T/g;
		$insert_line =~ s/$StartDate/$NewStartDate/g;
		
		$output_string=$output_string.$insert_line;
		
			}
			
		print $out $output_string;
	
		close $in;
		close $out;
		
	} else {
		printToLogFile(strftime("%Y/%m/%d %H:%M:%S", localtime)."$file to $outputDirectory_path/$file_node_type/$file_node_name/Day_$commonDays{$date}/$file_name\n");
		copy_file_to("$file","$outputDirectory_path/$file_node_type/$file_node_name/Day_$commonDays{$date}/$file_name",0);
	}
	
}
##-----------------------------------------------------------------------------------------------------------------------------------##

sub copy_file_to{
	$copy_from=$_[0];
	$copy_to=$_[1];
	$ow_move=$_[2];
	if($moveStatus eq "M") {
	move("$copy_from","$copy_to") or abort_script(strftime("%Y/%m/%d %H:%M:%S", localtime)." ABORT - $moveWord file $copy_from to $copy_to failed. \n",1005);
	} elsif($ow_move == 1) {
	move("$copy_from","$copy_to") or abort_script(strftime("%Y/%m/%d %H:%M:%S", localtime)." ABORT - Moving file $copy_from to $copy_to failed. \n",1005);
	} elsif ($moveStatus eq "C"){
	copy("$copy_from","$copy_to") or abort_script(strftime("%Y/%m/%d %H:%M:%S", localtime)." ABORT - $moveWord file $copy_from to $copy_to failed.\n",1005);
	} elsif ($moveStatus eq "S"){
	symlink("$copy_from","$copy_to") or abort_script(strftime("%Y/%m/%d %H:%M:%S", localtime)." ABORT - $moveWord file $copy_from to $copy_to failed. \n",1005);
	}
	
	
}
##-----------------------------------------------------------------------------------------------------------------------------------##

sub countFile{

    my ($ref) = @_;

    foreach my $dir (@$ref) {
        $dir = readlink $dir and chop $dir if -l $dir;    # read link

        next unless opendir(my $dir_h, $dir);             # open dir or next
        my @dirs;
        while (defined(my $file = readdir $dir_h)) {
            if ($file eq '.' or $file eq '..') {
                next;
            }
			
            if (-d "$dir/$file") {
                ++$d;                                     # counting dirs
                push @dirs, "$dir/$file";
            }
            elsif(-f _){
                ++$f;				# counting files
				my ($StartDate,$EndDate)=$file=~ m/^\w*A(\d{8})\.\d{4}\+\d{4}-(\d{8})\.\d{4}\+\d{4}\S+/;
				
            }
        }
        closedir $dir_h;
        countFile(\@dirs);
		
    }
return ($f, $d);
}
##-----------------------------------------------------------------------------------------------------------------------------------##

sub createPropertiesFile{
	my $node_dir=$_[0];
	
	my $propertiesFile = "";
	my $output_string="";
	$match_name=(split(/\//, $node_dir))[-2]."/".(split(/\//, $node_dir))[-1];
	$node=(split(/\//, $node_dir))[-2];
	$node_name=(split(/\//, $node_dir))[-1];
	$propertiesFile = $outputDirectory_path.'/'.$node."/properties_$node_name.txt";
	
	printToLogFile(strftime("%Y/%m/%d %H:%M:%S", localtime)." Creating properties file for node -> $match_name . \n");
	
	if( -e $propertiesFile ){
		unlink($propertiesFile);
	}
	open(my $propFile, '>', $propertiesFile) or abort_script(strftime("%Y/%m/%d %H:%M:%S", localtime)." Could not open file '$propertiesFile.\n",1006);
	
    my @dir = -d $node_dir ? $node_dir : next;
    ($f, $d) = (0, 0);
    ($f, $d) = countFile(\@dir);
	$output_string="\n#######################Properties#############################\n";
	$output_string=$output_string."\t\tNode: $node\t\tNode name: $node_name\n";
	$output_string=$output_string."\t\tNumber Of Files: $f\n\t\tNumber Of Days: $d\n\n";
	$output_string=$output_string."\t\tROP\t\tFILE\n";
	for (my $i=0; $i<$num_of_rops; $i+=1){
		$output_string=$output_string."\t\t$rop[$i]\t\t$rop_names[$i]\n" if $rop_names[$i] =~ m/$match_name/;
	}
	$output_string=$output_string."##############################################################\n\n";
	printToLogFile($output_string);
	print $propFile $output_string;
	close $propFile;
}
##-----------------------------------------------------------------------------------------------------------------------------------##
