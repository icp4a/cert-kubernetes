#!/usr/bin/env perl
#
# IBM Confidential
# OCO Source Materials
# 5737-I23
# Copyright IBM Corp. 2018 - 2022
# The source code for this program is not published or otherwise divested of its trade secrets, irrespective of what has been deposited with the U.S Copyright Office.
#

use strict;
use warnings;
use utf8;

use Text::CSV_XS qw( csv );
use File::Basename;

use Data::Dumper;
use Getopt::Long;

# Contains a filehandle for each lob file to read… so the program doesn't waste
# time openinng and closing them
my %lobs_filehandles;

my %tabledesc;
my $data_directory;
my $help;
my $onlytable;
my $dbencoding="utf8";
my $parallelism=1;
my $outcommand;

sub get_lob
{
	my ($filename,$start,$to_read,$fh_out,$isblob)=@_;
	if ($to_read == -1)
	{
		# That's the way DB2 presents null lobs… length of -1
		return '\N';
	}

	if ($isblob)
	{
		# Header for an hex-escaped LOB
		print $fh_out '\\\\x';
	}

	# We open BLOBS in raw, CLOBS in utf8. So we may have 2 different descriptors for the same file, I don't know what DB2 might do
	unless (exists $lobs_filehandles{$filename})
	{
		open my $fh,"<:raw",$filename or die "Cannot open $filename: $!";
		$lobs_filehandles{$filename}=$fh;
	}
	my $fh=$lobs_filehandles{$filename};

	seek $fh,$start,0; # O means it is an absolute position
	# Ok, read what we have to
	while ($to_read >0)
	{
		# Read at most 4k
		my $bytes_to_read=$to_read>4096?4096:$to_read;
		my $data;
		my $bytes_read=read $fh, $data, $bytes_to_read;
		die "Cannot read $bytes_to_read from $filename: $!" unless (defined $bytes_read and $bytes_read > 0);
		$to_read-=$bytes_read;
		if ($isblob)
		{
			print $fh_out unpack('H*',$data); # Produce the two hex characters per byte, high nibble first
		}
		else
		{
			# Protect \r and \n
			$data =~ s/\\/\\\\/g;
			$data =~ s/\t/\\t/g;
			$data =~ s/\n/\\n/g;
			$data =~ s/\r/\\r/g;


			print $fh_out $data;
		}
	}
}


# Reads a CSV file, and prints it to the filehandle provided (it may be stdout)
sub read_from_csv
{
	my ($schema,$table)=@_;
	my $basename_in=$table . '.del';
	my $dirname_in=$data_directory;
	my $filename_in=get_del_file_path($schema,$table);
	my $filename_out=get_bin_file_path($schema,$table);
	my $fh_out;
	if (defined $outcommand)
	{
		# Open the file to write
		open $fh_out, ">", $filename_out or die "Cannot open $filename_out for writing";
		#open $fh_out,"|-",$outcommand or die "Cannot run $outcommand as an output command";
	}
	else
	{
		$fh_out=*STDOUT;
	}
	binmode($fh_out, ":utf8");


	my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1 });

	open my $fh_in, "<:encoding(".$dbencoding.")", $filename_in or die "cannot open $filename_in for reading: $!";

	# Put the whole thing in a transaction. It will produce no journal if database isn't archiving
	#print $fh_out "BEGIN;\n";
	#print $fh_out "TRUNCATE TABLE $schema\.$table;\n";
	#print $fh_out "SET client_encoding = 'UTF8';\n";
	#print $fh_out "COPY $schema\.$table FROM STDIN;\n";

	# Prepare a memory structure to determine faster the type of a column
	# 1: CLOB, 2: BLOB, 3: Timestapm, 100: Whatever (add values if necessary)
	my @coltype;
	my @colnull;
	for (my $i=0; $i<=$#{$tabledesc{$schema}->{$table}};$i++)
	{
		my $type=$tabledesc{$schema}->{$table}->[$i]->{TYPE};
		if ($type =~ /^CLOB/)
		{
			$coltype[$i]=1;
		}
		elsif ($type =~ /^BLOB/)
		{
			$coltype[$i]=2;
		}
		elsif ($type =~ /^TIMESTAMP/)
		{
			$coltype[$i]=3;
		}
		elsif ($type =~ /^TIME/)
		{
			$coltype[$i]=4;
		}
		else
		{
			$coltype[$i]=100;
		}
		$colnull[$i]=$tabledesc{$schema}->{$table}->[$i]->{NULL};
	}
	my $corrected_nulls=0;
	while (my $row = $csv->getline ($fh_in)) {
		my $outrow='';
		my $rownum=$#$row;
		for (my $num=0;$num<=$rownum;$num++)
		{
			if ($num > 0)
			{
				$outrow.= "\t";
			}
			my $field=$row->[$num];
			my $fieldtype=$coltype[$num];
			if ($field eq '') # fast exit for empty (should mean null)
			{
				if ($colnull[$num] == 1)
				{
					$field = '\N';
				}
				# No need to set it at '' if null isn't authorized, it is already
				$outrow.= $field;
				next;
			}
			if ($fieldtype == 1 or $fieldtype ==2 ) # LOB
			{
				# Print what we have in outrow and clean it. We will output the LOB piece by piece
				print $fh_out $outrow;
				$outrow='';


				# FIXME: compile it once per file ?
				$field =~ /^($basename_in\.\d+\.lob)\.(\d+)\.(\d+)\/$/ or die "Cannot understand LOB format";
				{
					# There is a LOB in this… we need to fetch it from another file, and escape it postgresql-style
					# We have to check if this is a CLOB (just include it), or a BLOB (protect it with escaping)

					if ( $fieldtype == 1) # CLOB
					{
						get_lob($dirname_in.'/'.$1,$2,$3,$fh_out,0);
					}
					elsif ( $fieldtype == 2) # BLOB
					{
						get_lob($dirname_in.'/'.$1,$2,$3,$fh_out,1);
					}
				}
				$field=''; # We remove the field, get_lob has done the work
			}
			elsif ($fieldtype == 3) # Timestamp
			{
				$field =~ /^(\d{4}-\d{2}-\d{2})-(\d{2})\.(\d{2})\.(\d{2})\.(\d{6})$/ or die "I don't understand $field as a timestamp";
				$field = "$1 $2:$3:$4.$5";
			}
			elsif ($fieldtype == 4) # Time
			{
				$field =~ s/\./:/g;
			}
			else
			{
				$field =~ s/\\/\\\\/g;
				$field =~ s/\t/\\t/g;
				$field =~ s/\n/\\n/g;
				$field =~ s/\r/\\r/g;
				my $tmp_corrected_nulls=($field =~ tr/\000//d);
				$corrected_nulls+=$tmp_corrected_nulls;

			}
			$outrow.= $field;
		}
		$outrow.= "\n";
		print $fh_out $outrow;
	}
	#print $fh_out "\\.\n";
	#print $fh_out "COMMIT;\n";
	close $fh_in;
	if ($outcommand)
	{
		close $fh_out;
	}
	# Close all the filehandles to lob files
	%lobs_filehandles=();
	if ($corrected_nulls)
	{
		print STDERR "Warning: I had to remove $corrected_nulls null characters from $schema.$table\n";
	}
}

sub load_tabledesc
{
	my ($tabledescpath)=@_;
	open my $fh_desc,"<",$tabledescpath or die "Cannot open $tabledescpath, $!";
	my ($schema,$table,$col,$coltype,$colnum,$null);
	while (my $line=<$fh_desc>)
	{
		if ($line =~ /^\t(.*?)\t(.*?)\t(.*?)$/)
		{
			($col,$coltype,$null)=($1,$2,$3);
			$tabledesc{$schema}->{$table}->[$colnum]->{TYPE}=$coltype;
			$tabledesc{$schema}->{$table}->[$colnum]->{NAME}=$col;
			if ($null eq 'NULL')
			{
				$tabledesc{$schema}->{$table}->[$colnum]->{NULL}=1;
			}
			else
			{
				$tabledesc{$schema}->{$table}->[$colnum]->{NULL}=0;
			}
			$colnum++;
		}
		elsif ($line =~ /^(.*?)\t(.*?)$/)
		{
			$colnum=0;
			($schema,$table)=($1,$2);
		}
	}
	close $fh_desc;
}

# Do all tables stored in %tabledesc
sub do_all_tables
{
	my $running=0;
	foreach my $schema (sort(keys %tabledesc))
	{
		foreach my $table (sort(keys %{$tabledesc{$schema}}))
		{

			if ($^O =~  "MSWin32") {
				# No fork for Windows
				if (-f get_del_file_path($schema,$table))
				{
					print STDERR "Starting work on $schema.$table\n";
					read_from_csv($schema,$table);
				}
				else
				{
					print STDERR "No file found for $schema.$table\n";
				}
				next;
			}

			if ($running>=$parallelism)
			{
				my $deadchild;
				do
				{
					$deadchild=wait(); # Wait for a child to finish
				} until ($deadchild > 0);
				$running--;
			}
			my $son=fork();
			if ($son)
			{
				# Father, account for the new son
				$running++;
				print STDERR "Starting work on $schema.$table\n";
			}
			else
			{
				# Son, do the real work !
				read_from_csv($schema,$table);
				exit;
			}

		}
	}
	while ($running >0)
	{
		wait();
		$running--;
	}
}

sub get_del_file_path
{
	my ($schema,$table)=@_;
	my $filename_path=$data_directory . '/' . $table . '.del';
	return $filename_path;
}

sub get_bin_file_path
{
	my ($schema,$table)=@_;
	my $filename_path=$data_directory . '/' . $table . '.BIN';
	return $filename_path;
}

sub usage
{
	print STDERR "$0:\n",
	" -d export_directory\n",
	" -h this help\n",
	" [-j parallel_jobs]\n",
	" [-o command_to_pipe_to]\n",
	" [-t table (SCHEMA.TABLE)]\n",
	" [ -e encoding of source database]\n",
	" Parallel jobs work on several tables. There is no point in doing this with -t\n";

	die "FAIL";
}

my $options = GetOptions("d=s"	  => \$data_directory,
                         "h"      => \$help,
						 "j=i"	  => \$parallelism,
						 "o=s"	  => \$outcommand,
						 "t=s"	  => \$onlytable,
						 "e=s"	  => \$dbencoding,
                         );

unless (defined $data_directory)
{
	print STDERR "No data directory provided\n";
	usage();
}

if ($parallelism > 1)
{
	unless (defined $outcommand)
	{
		print STDERR "You have to provide a command with -o if you are using parallel mode\n";
		usage();
	}
}

$data_directory =~ s/(\/+|\\+)$//; # Remove the trailing / and \

# First, read the TABLEDESC file and store it
load_tabledesc($data_directory.'/TABLEDESC');
#print Dumper(\%tabledesc);

if ($onlytable)
{
	$onlytable =~ /^(.*)\.(.*)$/ or die "Invalid table name";
	read_from_csv($1,$2);
}
else
{
	do_all_tables();
}
