setBatchMode(true);

dir1=getDirectory("input");
list=getFileList(dir1);

for(i=0; i<list.length; i++){
	open(list[i]);
	run("Conversions...", " ");
	run("16-bit");
	saveAs("tiff",dir1+list[i]);
	close();
	}