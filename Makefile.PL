#!/usr/bin/env perl
# $File: //member/autrijus/DBIx-ReportBuilder/Makefile.PL $ $Author: autrijus $
# $Revision: #8 $ $Change: 8721 $ $DateTime: 2003/11/06 16:06:31 $

use 5.006;
use inc::Module::Install;

warn << '.';
### PLEASE NOTE ##############################################

This is *PRE-ALPHA* code.  Until the official release of the
RTx::Report extension, using this module for anything (except
for learning purporses) is strongly discouraged.

##############################################################
.

author		('Autrijus Tang (autrijus@autrijus.org)');
name		('DBIx-ReportBuilder');
abstract	('Interactive SQL report generator');
version_from	('lib/DBIx/ReportBuilder.pm');
requires	(
    'DBIx::SearchBuilder'   => '0.90',
    'XML::Twig'		    => '3.00',
    'GD::Graph'             => '0.01',
    'GD::Graph3d'           => '0.61',
    'Chart::Math::Axis'     => '0.1',
    'MIME::Base64'          => '2.12',
    'Image::Size'           => '0.01',
);

sign		(1);
license		('perl');
include_deps	('Test::More', 5.006);
build_requires	('Test::More', 0);

&Meta->write;
&Makefile->write;
