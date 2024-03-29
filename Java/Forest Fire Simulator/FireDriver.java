import java.util.Scanner; 							//import scanner

public class FireDriver {
	
										// POST: trees = "T" or "-", capacity > 0, increment >= 0 and < capacity
	public static String[][] burn(String[][] trees, int capacity, int increment) { 
		if (increment == 0) { 						// Burn the first row of trees
			for (int c = 0; c < capacity; c++) {
				if (trees[increment][c] == "T") {
					trees[increment][c] = "B";
				}
			}
		}else {								// Obtain row above current row to check for burnt trees
			String[] previousRow = trees[increment-1]; 
			for (int i = 0; i < capacity; i++) {
				if (previousRow[i] == "B") {
										// CHECK: DOWN
					if (trees[increment][i] == "T") { 
						trees[increment][i] = "B";
					}
					if (i >= 1) {				// CHECK: DOWN LEFT
						if (trees[increment][i-1] == "T") { 
							trees[increment][i-1] = "B";
						}
					}
					
					if (i < capacity-1) {			// CHECK: DOWN RIGHT
						if (trees[increment][i+1] == "T") { 
							trees[increment][i+1] = "B";
						}
					}
					
				}
			}
		}
		return trees; 							// POST: return burnt forest of trees
	}
										// PRE: numtrees > 0, capacity > 0
	public static String[][] makeTrees(String[][] trees, int numtrees, int capacity){ 
		int treecount = 0;
		while (treecount < numtrees) { 					// Loop while numtrees has not been met
			for (int r = 0; r < capacity; r++) {
				for (int c = 0; c < capacity; c++) {
					if (trees[r][c] != "T") {
										// 20% chance (random num) to become tree
						int randomnum = (int) (Math.random() * 5) + 1; 
						if (randomnum == 4) { 
										// Make a tree
							trees[r][c] = "T"; 
							treecount++;
										// Check if numtrees has been met
							if (treecount >= numtrees) { 
										// POST: return fully planted forest of trees
								return trees; 
							}
						}else {
							trees[r][c] = "-"; 	// Make an empty space
						}
					}
				}
			}
		}
		return trees; 							// POST: return fully planted forest of trees
	}
	
	public static int checkBurned(String[][] trees, int capacity) { 	// PRE: trees == "T" or "-", capacity > 0
		int treecount = 0;
		for (int r = 0; r < capacity; r++) {
			for (int c = 0; c < capacity; c++) {
				if (trees[r][c] == "B") { 			// Burnt tree found
					treecount++;
				}
			}
		}
		return treecount; 						// POST: return number of trees burnt
	}
	
	public static void main(String[] args) {
		Scanner scan = new Scanner(System.in);
		
		int capacity = 0; 						// Number of plots for trees
		double density = 0.0; 						// Density of forest
		double population = 0.0; 					// Percentage of trees made
		int numtrees = 0; 						// Actual number of trees to be made
		double burned = 0.0; 						// Percentage of trees burnt after fire
		String status = "Fire burned out."; 				// Status if burnt through or not
		
		while (capacity < 10 || capacity > 3000) {			// Error check for capacity
			System.out.print("Enter number of trees: ");
			capacity = scan.nextInt(); 				// Input capacity
		}
		
		while (density < 0.2 || density > 0.8) {			// Error check for density
			System.out.print("Enter density (0.2-0.8): ");
			density = scan.nextDouble(); 				// Input density
		}
		
		numtrees = (int) (density * (capacity * capacity)); 		// Find number of trees based off density
		
		String[][] trees = new String[capacity][capacity]; 		// Create forest array
		trees = makeTrees(trees,numtrees,capacity); 			// Randomly plant trees
		
		population = (double) numtrees/ (capacity * capacity); 		// Determine percentage of trees in forest
		
		System.out.println();
		System.out.println("The original forest: ");
		
		for (int r = 0; r < capacity; r++) { 				// Output original forest
			for (int c = 0; c < capacity; c++) {
				System.out.print(trees[r][c] + " ");
			}
			System.out.println();
		}
		
		System.out.println("Percent populated: " + population);//population);
		
		System.out.println();
		
		for (int i = 0; i < capacity; i++) {
			trees = burn(trees,capacity,i); 			// Start burning trees
		}
		
		System.out.println();
		System.out.println("The final forest: ");
		
		for (int r = 0; r < capacity; r++) { 				// Output burnt forest
			for (int c = 0; c < capacity; c++) {
				System.out.print(trees[r][c] + " ");
			}
			System.out.println();
		}
		
		burned = checkBurned(trees,capacity); 				// Calculate percent burnt
		burned /= (capacity * capacity);
		
		System.out.println("Percent burned: " + burned);
		
		for (int r = 0; r < capacity; r++) { 				// Determine whether it burnt through or not
			if (trees[capacity-1][r] == "B") {
				status = "Fire burned through.";
			}
		}
		
		System.out.println(status); 					// Output whether burnt through or not

		scan.close();
	}
}
