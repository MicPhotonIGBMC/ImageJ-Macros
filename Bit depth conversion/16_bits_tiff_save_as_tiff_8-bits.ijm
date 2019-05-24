// "BatchProcessFolders"
//
// This macro batch processes all the TIFF files in a folder and any
// subfolders in that folder. In this example, it saves the files
// as 8-bits TIFF files. For other kinds of processing,
// edit the processFile() function at the end of this macro.

requires("1.33s"); 
dir1 = getDirectory("Choose a Directory ");
dir2 = getDirectory("Choose Destination Directory");	   
setBatchMode(true);
   count = 0;
   countFiles(dir1);
   n = 0;
   processFiles(dir1);
print(count+" files processed");
   
   function countFiles(dir1) {
      list = getFileList(dir1);
      for (i=0; i<list.length; i++) {
          if (endsWith(list[i], "/"))
              countFiles(""+dir1+list[i]);
          else
              count++;
      }
  }

   function processFiles(dir1) {
      list = getFileList(dir1);
      for (i=0; i<list.length; i++) {
          if (endsWith(list[i], "/"))
              processFiles(""+dir1+list[i]);
          else {
             showProgress(n++, count);
             path = dir1+list[i];
             processFile(path);
          }
      }
 

  function processFile(path) { 
        path = dir1 + list[i];
	open(path); 
	//run("Channels Tool... ");
	//Stack.setDisplayMode("composite");
	run("8-bit");
	saveAs("Tiff", dir2+list[i]); // edit for other processes
	close();
      }
  }
