/* Bertrand Vernay
 * Imaging Centre IGBMC
 * vernayb@igbmc.fr
 * September 2020
 * 
 * Requirement:
 * 	- a folder containing a png image and a ROiSet named "image name"_RoiSet.zip
 * 	
 * How to use:
 * 	- start the macro
 * 	- select the image
 * 	- once the macro is finished, open the txt file in Fiji and save as .xml
 * 	- the xml file in now readable by LabelImg https://github.com/tzutalin/labelImg
 * 
 * Improvement:
 *  - why changign txt to xml does not make the xml file readbale. Have to open iin Fiji and save as xml.
 * 
*/

print("\\Clear");
roiManager("reset");

// Open the png file
open();
name = File.nameWithoutExtension;

// Get the name of the image containing folder
dir = File.directory;
parentDir = File.getParent(dir);
folder = substring(dir, lengthOf(parentDir)+1, lengthOf(dir)-1 );

//get the dimensions of the image
getDimensions(width, height, channels, slices, frames);

// Open the corresponding RoiSet
open(dir+name+"_RoiSet.zip");

// Tag name selection (single tag for the moment)
tagName = getString("Tag for the annotation", "yeast");

// XML format for LabelImg (https://github.com/tzutalin/labelImg)
/*
<?xml version='1.0'?>"
<annotation>
	<folder></folder>
	<filename></filename>
	<path></path>
	<source>
		<database></database>
	</source>
	<size>
		<width></width>
		<height></height>
		<depth></depth>
	</size>
	<segmented></segmented>
	<object>
		<name></name>
		<pose></pose>
		<truncated></truncated>
		<difficult></difficult>
		<bndbox>
			<xmin></xmin>
			<ymin></ymin>
			<xmax></xmax>
			<ymax></ymax>
		</bndbox>
	</object>
</annotation>

*/

// Builging the text file in log for final xml
print("<annotation>");
	print("\t<folder>"+folder+"</folder>");
	print("\t<filename>"+name+".png</filename>");
	print("\t<path>"+dir+name+".png</path>");
	print("\t<source>");
		print("\t\t<database>Unknown</database>");
	print("\t</source>");
	print("\t<size>");
		print("\t\t<width>"+width+"</width>");
		print("\t\t<height>"+height+"</height>");
		print("\t\t<depth>1"+"</depth>");
	print("\t</size>");
	print("\t<segmented>0</segmented>");
	for (i = 0; i<roiManager("count"); i++){
		print("\t<object>");
			print("\t\t<name>"+tagName+"</name>");
			print("\t\t<pose>Unspecified</pose>");
			print("\t\t<truncated>0</truncated>");
			print("\t\t<difficult>0</difficult>");
			roiManager("select", i);
			getBoundingRect(x, y, roiWidth, roiHeight);
				print("\t\t<bndbox>");
					print("\t\t\t<xmin>"+x+"</xmin>");
					print("\t\t\t<ymin>"+y+"</ymin>");
					print("\t\t\t<xmax>"+(roiWidth+x)+"</xmax>");
					print("\t\t\t<ymax>"+(roiHeight+y)+"</ymax>");
				print("\t\t</bndbox>");
		print("\t</object>");
		}
print("</annotation>");

// Save log window as ."image name".txt
selectWindow("Log");
saveAs("Text", dir+name+".txt");
close();