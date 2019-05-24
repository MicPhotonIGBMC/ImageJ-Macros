print("\\Clear");
setBatchMode(false);
tileX=getNumber("tiles in X", 13);
tileY=getNumber("tiles in Y", 13);

dir2=getDirectory("Saving raw tiles");
//dir3=getDirectory("Saving corrected tiles");
openImage=getImageID();
//run("Z Project...", "projection=[Average Intensity]");
averageID=getImageID();
for (i=0; i<tileY; i++){    //tiles in Y axis
	for(j=0; j<tileX; j++){  //tiles in X axis
		selectImage(averageID);
		x=j*511;  //pixels - can make more fancy by adding line to divide pixels by number of tiles inputed at start
		y=i*511;
		makeRectangle(x, y+1, 511, 511);
		run("Duplicate...", " ");
		saveAs("tiff", dir2+"tile"+"_X_"+i+"_Y_"+j+".tiff");
		close();
	}
}

listDir2=getFileList(dir2);
path=dir2+listDir2[0];
run("Image Sequence...", "open=path sort");
rawStackID=getImageID();
rawStacktitle=getTitle();
run("Z Project...", "projection=[Average Intensity]");
avgID=getImageID();
avgTitle=getTitle();
run("Gaussian Blur...", "sigma=20");
getStatistics(area, mean);
run("Calculator Plus", "i1="+rawStacktitle+" i2="+avgTitle+" operation=[Divide: i2 = (i1/i2) x k1 + k2] k1="+mean+" k2=0 create");
resultID=getImageID();
run("Make Montage...", "columns="+tileY+" rows="+tileX+" scale=1");
selectImage(avgID);
close();
selectImage(rawStackID);
close();
