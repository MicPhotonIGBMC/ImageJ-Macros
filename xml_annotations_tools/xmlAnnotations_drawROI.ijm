/* Bertrand Vernay
 * Imaging Centre IGBMC
 * vernayb@igbmc.fr
 * September 2020
 * 
 * Requirement:
 * 	- a folder containing a png image and a xml file 
 * (created in LabelImg https://github.com/tzutalin/labelImg) with the same name
 * 	
 * How to use:
 * 	- start the macro
 * 	- select the xml file
 * 	- the macro create ROIs from the xml annotations and save them in a RoiSet
 * 	
*/

print("\\Clear");
roiManager("reset");

annotationsXML = File.openAsString("");
name = File.nameWithoutExtension;
dir = File.directory;
print(name, dir);
path = dir+name+".png"
open(path);

while (lengthOf(annotationsXML) > 0){
	xMIN_start = indexOf(annotationsXML, "<xmin>");
	xMIN_end = indexOf(annotationsXML, "</xmin>");
	yMIN_start = indexOf(annotationsXML, "<ymin>");
	yMIN_end = indexOf(annotationsXML, "</ymin>");
	xMAX_start = indexOf(annotationsXML, "<xmax>");
	xMAX_end = indexOf(annotationsXML, "</xmax>");
	yMAX_start = indexOf(annotationsXML, "<ymax>");
	yMAX_end = indexOf(annotationsXML, "</ymax>");
	if (xMIN_start == -1){
		roiManager("deselect");
		roiManager("Save", dir+name+"_RoiSet.zip");
		roiManager("Show All");
		exit("Processing finished");
	}
	else {
	xmin = substring(annotationsXML, xMIN_start+6, xMIN_end);
	ymin = substring(annotationsXML, yMIN_start+6, yMIN_end);
	xmax = substring(annotationsXML, xMAX_start+6, xMAX_end);
	ymax = substring(annotationsXML, yMAX_start+6, yMAX_end);
	makeRectangle(xmin, ymin, xmax-xmin, ymax-ymin);
	roiManager("Add");
	annotationsXML = substring(annotationsXML, yMAX_end+7, lengthOf(annotationsXML));
	}
}