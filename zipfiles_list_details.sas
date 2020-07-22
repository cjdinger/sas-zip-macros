/* Produce a list of ZIP files and their entries from a single folder */
%macro listzipcontents (
     targdir= /* a system folder that contains ZIP files       */, 
     outlist= /* output data set for list of files and members */);
  filename targdir "&targdir";
 
  /* Gather all ZIP files in a given folder                */
  /* Searches just one folder, not subfolders              */
  /* for a fancier example see                             */
  /* http://support.sas.com/kb/45/805.html (Full Code tab) */
  data _zipfiles;
    length fid 8;
    fid=dopen('targdir');
 
    if fid=0 then
      stop;
    memcount=dnum(fid);
 
    /* Find all ZIP files.  GZ files added in 9.4 Maint 5 */
    do i=1 to memcount;
      memname=dread(fid,i);
      if lowcase( scan( memname,-1,'.')) in ('zip') then
        output;
    end;
 
    rc=dclose(fid);
  run;
 
  filename targdir clear;
 
  /* get the memnames into macro vars */ 
  proc sql noprint;
    select memname into: zname1- from _zipfiles;
    %let zipcount=&sqlobs;
  quit;
 
  /* for all ZIP files, gather the members */
  %do i = 1 %to &zipcount;
    %put &targdir/&&zname&i;
    filename targzip ZIP "&targdir/&&zname&i";
 
    data _contents&i.(keep=zip memname);
      length zip $200 memname $200 ;
      zip="&targdir/&&zname&i";
      fid=dopen("targzip");
 
      if fid=0 then
        stop;
      memcount=dnum(fid);
 
      do i=1 to memcount;
        memname=dread(fid,i);
 
        /* save only full file names, not directory names */
        if (first(reverse(trim(memname))) ^='/') then
          output;
      end;
 
      rc=dclose(fid);
    run;
 
    filename targzip clear;
  %end;
 
  /* Combine the member names into a single data set        */
  /* the colon notation matches all files with "_contents" prefix */
  data &outlist.;
    set _contents:;
  run;
 
  /* cleanup temp files */
  proc datasets lib=work nodetails nolist;
    delete _contents:;
    delete _zipfiles;
  run;
 
%mend;

/* Build the file details for a single ZIP member */
%macro getzipmemberinfo(
  f /* fileref of a ZIP/member= combination */,
  out /* output data set for details of just this ZIP member */);
  data &out.;
  length filename $ 200
         membername $ 200
		 filetime 8
		 filesize 8
		 compressedsize 8
		 compressedratio 8
		 CRC32 $ 8;
    keep filename 
         membername 
		 filetime 
		 filesize 
		 compressedsize 
		 compressedratio
		 CRC32;
	format filetime datetime20.
	       filesize sizekmg10.2
		   compressedsize sizekmg10.2
           compressedratio percent6.;

    /* These FINFO attributes are specific to ZIP file members */
    fId = fopen("&f","S");
    if fID then
	    do;
	     infonum=foptnum(fid);
		     do i=1 to infonum;
		      infoname=foptname(fid,i);
			  select (infoname);
			   when ('Filename') filename=finfo(fid,infoname);
			   when ('Member Name') membername=finfo(fid,infoname);
			   when ('Size') filesize=input(finfo(fid,infoname),15.);
			   when ('Compressed Size') compressedsize=input(finfo(fid,infoname),15.);
			   when ('CRC-32') crc32=finfo(fid,infoname);
			   when ('Date/Time') filetime=input(finfo(fid,infoname),anydtdtm.);
			  end;    
	     end;
	 compressedratio = compressedsize / filesize;
	 output;
     fId = fClose( fId );
   end;
  run;
%mend;

/* Given a data set of ZIP file names and entries, assemble the member details */
/* Assumes input contains 'zip' and 'memname' columns, as produced by          */
/* the %listzipcontents() macro.                                               */
%macro getZipDetails(
   inlist= /* two-column data set with zip (full path of ZIP file) and memname (entry in ZIP file) */,
   outlist= /* data set for output details */);

    /* Build a list of FILENAME statements */
	proc sql noprint;
	 select cat('FILENAME f ZIP "',trim(zip),'" member="',trim(memname),'";') length=300 
	   into: fnames1-  from &inlist.;
	 %let fcount=&sqlobs.;
	quit;

  /* One by one, assign the fileref to a ZIP member, fetch details, clear fileref */
  %do i = 1 %to &fcount;
    &&fnames&i.;
	%getzipmemberinfo(f,_deets&i.);
	filename f clear;
  %end;

  /* aggegate results into a single output */
  data &outlist.;
   set _deets:;
  run;

  /* Clean up temp files */
  proc datasets lib=work nodetails nolist;
  delete _deets:;
  quit;
%mend;

/* To use: first run LISTZIPCONTENTS with folder that contains    */
/* ZIP files you want details for, then run GETZIPDETAILS on the  */
/* output of that. */
/* Output: a SAS data set with zip member details.                */
/*

filename                                     membername                                                           filetime      filesize    compressedsize    compressedratio    CRC32

SAS.MacroViewer.zip                          SAS.MacroViewer.dll                                        29SEP2012:09:49:18      139.00KB         51.32KB            37%          054AEBC6
SASPress.CustomTasks.DS2Datalines_src.zip    src/Properties/AssemblyInfo.cs                             27NOV2012:20:57:06        1.11KB          0.51KB            46%          FAC88DED
SASPress.Facebook_src.zip                    src/FacebookConnector/Properties/AssemblyInfo.cs           16JAN2011:12:06:24        1.43KB          0.63KB            44%          2C86F829
SASPress.Facebook_src.zip                    src/FacebookConnector/Properties/Resources.Designer.cs     21JAN2011:20:04:54        2.78KB          0.90KB            32%          C7508420
SASPress.Facebook_src.zip                    src/FacebookConnector/Properties/Resources.resx            21JAN2011:20:04:54        5.82KB          1.48KB            25%          E0C8C87E
SASPress.Facebook_src.zip                    src/FacebookConnector/Properties/Settings.Designer.cs      19JAN2011:08:28:06        1.07KB          0.45KB            42%          4DDC113E
SASPress.Facebook_src.zip                    src/FacebookConnector/Properties/Settings.settings         16JAN2011:12:06:24        0.24KB          0.17KB            70%          12D89760
SASPress.Facebook_src.zip                    src/FacebookConnector/README.txt                           23JAN2011:13:12:38        5.12KB          2.08KB            41%          19CEF39C
SASPress.Facebook_src.zip                    src/README.txt                                             23JAN2011:13:12:38        5.12KB          2.08KB            41%          19CEF39C

*/

/* Sample use:

  %listzipcontents (targdir=C:\Projects\ZIPPED_Examples, outlist=work.zipfiles);
  %getZipDetails (inlist=work.zipfiles, outlist=work.zipdetails);

*/