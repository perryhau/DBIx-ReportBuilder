@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
..\..\..\common\perl\bin\perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
..\..\..\common\perl\bin\perl -x -S %0 %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!perl
#line 15
use strict;
use File::Spec;
my $basedir = File::Spec->catdir($ENV{WINDIR}, 'TEMP', 'RG');
while (1) {
    sleep 1;
    # print "Looking into $basedir\n";
    foreach my $file (<$basedir/*.htm>) {
	open FH, $file or next;
        my $path;
	my $is_msword;
	while (<FH>) {
	    $is_msword = 1 if m{MSWord};
	    last if ($path) = m{"(file://.*)/"};
        }
        close FH;
        print "Processing $file on $path\n";

	require Win32::OLE;
	my $objServiceManager = Win32::OLE->new(
	    "com.sun.star.ServiceManager"
	) or die $!;
	my $objDesktop = $objServiceManager->createInstance(
	    "com.sun.star.frame.Desktop"
	);

	my $v1 = $objServiceManager->Bridge_GetStruct(
	    "com.sun.star.beans.PropertyValue"
	);

	$v1->{Name} = "Hidden";
	$v1->{Value} = 1;

	my $objDocument = $objDesktop->loadComponentFromURL(
	    "$path/out.html", "_blank", 0, [$v1],
	);

	$v1->{Name} = "FilterName";
	$v1->{Value} = ($is_msword ? "writer_web_StarOffice_XML_Writer" : "writer_web_pdf_Export");

	if ($objDocument) {
	    if ($is_msword) {
		$objDocument->storeToURL( "$path/out.sxw", [$v1] );
		$objDocument->dispose;

		$v1->{Name} = "Hidden";
		$v1->{Value} = 1;
		$objDocument = $objDesktop->loadComponentFromURL(
		    "$path/out.sxw", "_blank", 0, [$v1],
		);

		$v1->{Name} = "FilterName";
		$v1->{Value} = "MS Word 97";
		$objDocument->storeToURL( "$path/out.doc", [$v1] );
	    }
	    else {
		$objDocument->storeToURL( "$path/out.pdf", [$v1] );
	    }
	    $objDocument->dispose;
	}

        unlink $file;
    }
}
