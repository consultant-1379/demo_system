#!/usr/bin/perl
use POSIX qw/strftime/;
use Time::Local;
use Getopt::Long;
use File::Basename;

#Local variables
my ( $logging_status, $additional_output_dir, $input_file_path_and_name, $mz_output_dir, $input_file_path_and_name_tmp, $mzOutputPathAndFileName );

GetOptions(
    'l=s'   => \$logging_status,
    'a=s'     => \$additional_output_dir,
    'i=s'  => \$input_file_path_and_name,
    'o=s' => \$mz_output_dir,
);





sub checkArguments{

if ($input_file_path_and_name eq "" || $mz_output_dir eq "" || $logging_status eq "" ){
		usageMsg();
	}
else{
	changeFileDate();
	}
}


sub usageMsg{

		print "# Mandatory Fields"."\n";
		print "-i <input path and file> # This path to the file that is read and date is changed."."\n";
		print "-o <output directory for mediation zone> # The output path for MZ to consume the file"."\n";
		print "-c <[ON] or [OFF]> # gzip the output files"."\n";
		print "-l <[ON] or [OFF]> # Logging on or off."."\n";
		print "\n";
 		print "# Optional Fields"."\n";
		print "-a <Additional directory> # The directory to which additional file(s) will be consumed"."\n";
}


sub changeFileDate{


if ($logging_status eq "ON")
{
	print "DEBUG Input file: ".$input_file_path_and_name."\n";
	print "DEBUG Output directory: ".$mz_output_dir."\n";
	print "DEBUG Additional output directory: ".$additional_output_dir."\n";
	print "DEBUG logging is turned: ".$logging_status."\n";
    print "DEBUG Filename: ".basename($input_file_path_and_name)."\n";
}


	system("gunzip $input_file_path_and_name");
	$input_file_path_and_name =~ s/.gz//;

	my $inputFileNameOnly= basename($input_file_path_and_name);
	#The date is contained in the filename (e.g. A20131004.1600+0800-20131004.1615+0800_9_ebs) therefore we can simply substring the name to get year, month and day

	my $inputFileNameInfo=$inputFileNameOnly;

	#The above is filename is not true for the NFS files as they contain the node name (e.g. SGSN56S_A20140121.1015+0800-20140121.1030+0800_9_ebs.184), therefore we do a substring first to remove the node name
	if (index($inputFileNameInfo, "_A20") != -1) {
    		$inputFileNameInfo= substr($inputFileNameInfo, index($inputFileNameInfo, "_")+1);
	}

	
	
	my $fileDate = substr($inputFileNameInfo, 1, 8);
	my $fileYear = substr($fileDate, 0, 4);
	my $fileMonth = substr($fileDate, 4, 2);
	my $fileDay = substr($fileDate, 6, 2);

	my $fileTime = substr($inputFileNameInfo, 10, 4);
	my $fileHour = substr($fileTime, 0, 2);
	my $fileMinute = substr($fileTime, 2, 2);

	#my $fileTimeZone = substr($inputFileNameInfo, 14, 5);
	#my $fileTimeZoneHour = substr($fileTimeZone , 0, 3);
	#my $fileTimeZoneMinute = substr($fileTimeZone , 3, 2);

	
#       0    1     2    3     4    5     6     7     8
#    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =  gmtime(time);

	my @headerGMT = gmtime; #Auto constructing an array so as to not have to create a $sec,$wday,$yday and $isdst  yea yea i am lazy :)
	#@headerGMT[1] = ($fileTimeZoneHour*60)+"$TimeZoneMinute" - $fileMinute; #Minute
	@headerGMT[1] = $fileMinute; #Minute
	@headerGMT[2] = $fileHour; #Hour 
	@headerGMT[3] = $fileDay;  #Day
	@headerGMT[4] = $fileMonth-1; #Month (January is 0 in perl :) hence all months are minus one )


	my $headerDay=strftime("%d", @headerGMT);
	my $headerMonth=strftime("%m", @headerGMT);
	my $headerYear=strftime("%Y", @headerGMT);

	
      
		#need to remove the SGSN part of the file for CEP to process that data... if cep is at required to do so.
		#i.e. SGSN56S_A20140121.1015+0800-20140121.1030+0800_9_ebs.184 - File name
		# From: SGSN56S_A20140121.1015+0800-20140121.1030+0800_9_ebs.184 (is the $inputFileNameOnly variable)
		# To:   A20140121.1015+0800-20140121.1030+0800_9_ebs.184 (is the $inputFileNameInfo variable)

  	$mzOutputPathAndFileName = $mz_output_dir."/".$inputFileNameOnly;
 	my $cepOutputPathAndFileName = $additional_output_dir."/".$inputFileNameInfo;
	$input_file_path_and_name_tmp = $input_file_path_and_name."_tmp";

	#Check if the files already exist and if so delete them
	if ( -e $input_file_path_and_name_tmp ){
		unlink($input_file_path_and_name_tmp );
	}
	if ( -e $cepOutputPathAndFileName && $additional_output_dir ne ""  ){
		unlink($cepOutputPathAndFileName);
	}


#In case some logging is required 
if ($logging_status eq "ON"){
	print "DEBUG inputFileNameInfo ".$inputFileNameInfo. "\n";
	print "DEBUG headerDay ->" . $headerDay ."\n";
	print "DEBUG headerMonth" . $headerMonth."\n";
	print "DEBUG headerYear" . $headerYear."\n";
	print "DEBUG ".strftime("%Y/%m/%d %H:%M:%S", localtime)." Opening binary file : ".$input_file_path_and_name." to change date for new binary file : ".$input_file_path_and_name_tmp."\n";

}

if ($logging_status eq "ON" && $additional_output_dir ne ""  ){
		print strftime("%Y/%m/%d %H:%M:%S", localtime)." Opening binary file : ".$input_file_path_and_name." to change date for new binary file : ".$cepOutputPathAndFileName."\n";
	}


	unless(open INPUTFILE, $input_file_path_and_name) {
		die "\nUnable to open file: $input_file_path_and_name to read the contents of the file. Please check the files exists!\n";
	}
	
	unless(open OUTPUTFILE, ">>$input_file_path_and_name_tmp") {
		die "\nUnable to create $input_file_path_and_name_tmp\n";
	}
	#Only require a secondary output if CEP is specified
	if ( $additional_output_dir ne ""  ){
		unless(open OUTPUTFILE2, ">>$cepOutputPathAndFileName") {
			die "\nUnable to create $cepOutputPathAndFileName\n";
		}
	binmode(OUTPUTFILE2);
	}
	
	
	binmode(INPUTFILE);
	binmode(OUTPUTFILE);



	my $loopIterations  = -1;
	my ($data, $n);

	while (($n = read INPUTFILE, $data, 1) != 0) {
		
		$loopIterations++;
	
		#next if($loopIterations >= 5 && $loopIterations <= 8);
	    next if($loopIterations >= 14 && $loopIterations <= 17);
		if ($loopIterations == 18) {
			print OUTPUTFILE pack("n", $headerYear);
			print OUTPUTFILE pack("C", $headerMonth);
			print OUTPUTFILE pack("C", $headerDay);


		#Only require a secondary output if CEP is specified
		if ( $additional_output_dir ne ""  ){
			print OUTPUTFILE2 pack("n", $headerYear);
			print OUTPUTFILE2 pack("C", $headerMonth);
			print OUTPUTFILE2 pack("C", $headerDay);
		}



		}

		print OUTPUTFILE $data;

		#Only require a secondary output if CEP is specified
			if ( $additional_output_dir ne ""  ){
			print OUTPUTFILE2 $data;
		}
	}

	
	close INPUTFILE;
	close OUTPUTFILE;
	
		#Only require a secondary output if CEP is specified
			if ( $additional_output_dir ne ""  ){
		       close OUTPUTFILE2;
		}
}


##Where it all starts :)

checkArguments();

system("mv $input_file_path_and_name_tmp $input_file_path_and_name");
system("gzip -c $input_file_path_and_name > $mzOutputPathAndFileName.gz");
unlink($input_file_path_and_name);


