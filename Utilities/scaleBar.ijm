macro "Scale Bar Folder [1]" {
	setBatchMode(true);
	dir1 = getDirectory("Select the folder containing the images");
	dir2=getDirectory("Select the folder where to save the images with the scale bar");
	scaleBar=getNumber("Select the size of the scale bar", 10);
	list=getFileList(dir1);
	for(i=0; i<list.length; i++){
	openPath=dir1+list[i];
	open(openPath);	
	run("Scale Bar...", "width="+scaleBar+" height=4 font=14 color=White background=None location=[Lower Right] bold hide");  //to replace to change parameter
	//run("Scale Bar...", "width=10 height=4 font=14 color=White background=None location=[Lower Right] bold hide");
	savePath=dir2+list[i];
	saveAs("tiff",savePath);
	}
}

macro "Scale Bar single Image [2]" {
	scaleBar=getNumber("Select the size of the scale bar", 10);
	run("Scale Bar...", "width="+scaleBar+" height=4 font=14 color=White background=None location=[Lower Right] bold hide");  //to replace to change parameter
	}
}