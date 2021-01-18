/* July 2019
 * Erwan Grandgirard  & Bertand Vernay
 * grandgie@igbmc.fr & vernayb@igbmc.fr
 *  
 *  1- Open .lif serie, Spilt Chanel and save as *.*Tiff All chanel separately and composite  
 *  
 *  
*/ 
macro "Split and Save [F2]" {

// INITIALISE MACRO
print("\\Clear");
               
run("Bio-Formats Macro Extensions");	//enable macro functions for Bio-formats Plugin
print("select folder with your Data")
dir1 = getDirectory("Choose a Directory");
print("Select the Save Folder")
dir2 = getDirectory("Choose a Directory");
list = getFileList(dir1);
setBatchMode(true);
// PROCESS LIF FILES
for (i = 0; i < list.length; i++) {
		processFile(list[i]);
}

/// Requires run("Bio-Formats Macro Extensions");
function processFile(fileToProcess){
	path=dir1+fileToProcess;
	Ext.setId(path);
	Ext.getCurrentFile(fileToProcess);
	Ext.getSeriesCount(seriesCount); // this gets the number of series
	print("Processing the file = " + fileToProcess);
	// see http://imagej.1557.x6.nabble.com/multiple-series-with-bioformats-importer-td5003491.html
	for (j=0; j<seriesCount; j++) {
        Ext.setSeries(j);
        Ext.getSeriesName(seriesName);
		run("Bio-Formats Importer", "open=&path color_mode=Default view=Hyperstack stack_order=XYCZT series_"+j+1); 
		fileNameWithoutExtension = File.nameWithoutExtension;
		run("Split Channels");
		image1="C1-"+fileNameWithoutExtension+".lif - "+seriesName;
		selectWindow(image1);
		saveAs("tiff", dir2+image1+"_DAPI.tif");
		image2="C2-"+fileNameWithoutExtension+".lif - "+seriesName;
		selectWindow(image2);
		saveAs("tiff", dir2+image2+"_Ki67.tif");
		run("Close All");
	}
  }
}