macro "convert_32bit_ICS_to_16bit_fixed_range_0-65535 [F1]" {

print("\\Clear");
run("Conversions...", "scale");
setBatchMode(true);

inDir=getDirectory("Choose a Source directory");
outDir=getDirectory("Choose a Target directory");
list=getFileList(inDir);

minRange = getNumber("min value of range", 0);
maxRange = getNumber("max value of range", 65535);

for (i = 0; i < list.length; i++) {
	if (endsWith(list[i], ".ics")){
		print("Processing "+list[i]);
		path=inDir+list[i];
		run("Bio-Formats Importer", "open=path color_mode=Default view=Hyperstack stack_order=XYCZT");
		tempName=File.nameWithoutExtension;
		setMinAndMax(minRange, maxRange);
		call("ij.ImagePlus.setDefault16bitRange", 16);
		run("16-bit");
		saveAs("tiff", outDir+tempName+".tiff");
		close();
	}
}

print("***** DONE *****");
setBatchMode(false);
}