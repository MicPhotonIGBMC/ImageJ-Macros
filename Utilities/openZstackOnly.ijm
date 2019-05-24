print("\\Clear");
run("Bio-Formats Macro Extensions");

dir1= getDirectory("Select the directory containing the lif files to analyse");
list=getFileList(dir1);

// open lif file
for (i = 0; i < list.length; i++) {
	path=dir1+list[i];
	Ext.setId(path);
	Ext.getCurrentFile(list[i]);
	Ext.getSeriesCount(seriesCount);
	print("Processing "+list[i]);
	print(seriesCount + " images to check");
	for (j=0; j<seriesCount; j++) {
        Ext.setSeries(j);
        Ext.getSeriesName(seriesName);
        Ext.getSizeZ(sizeZ);
        if (sizeZ > 1){
        	print("z focal planes in image " + seriesName + " is "+sizeZ);
			run("Bio-Formats Importer", "open=&path color_mode=Default view=Hyperstack stack_order=XYCZT series_"+j+1); 
        }
	}
}

print("DONE");
