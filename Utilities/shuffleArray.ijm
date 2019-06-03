//From https://imagej.nih.gov/ij/macros/examples/RandomizeArray.txt

test = newArray(1,2,3,4,5,6,7,8,9,10);

shuffle(test);
Array.show(test);

function shuffle(array) {
	n = array.length;
	while (n > 1) {
		k = randomInt(n);     
		n--;                  
		temp = array[n];      
		array[n] = array[k];
		array[k] = temp;
	}
}



// returns a random number, 0 <= k < n
function randomInt(n) {
  return n * random();
} 