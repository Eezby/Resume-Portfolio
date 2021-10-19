
import java.util.Scanner;										 //import scanner

public class Runner {
	public static void main(String[] args) {
		
		final double FRICTION_COEFIFFICIENT = 1.23; 						// Declare constants
		final double RC_MODEL = 21.99;
		final double ED_MODEL = 24.99;
		
		int num_data_points = 0; 								// Declare and set variables
		String ski_id = "xxxxx";
		double friction_c = 0;
		double ski_price = 0;
		
		int rejected_skis = 0;
		double rejected_cost = 0;
		double rejected_percent = 0;
		
		double average = 0;
		
		Scanner scan = new Scanner(System.in); 							// Create Scanner
		
		System.out.println("Programmer: Ethan Esber");
		System.out.println();
		
		while (num_data_points <= 0) { 								// Prevent invalid inputs
			System.out.print("Enter number of data points: ");
			num_data_points = scan.nextInt();  						// Input number of data points
		}
		
		System.out.println();
		
		for (int i = 0; i < num_data_points; i++) {
			
			while (!ski_id.substring(0, 2).equalsIgnoreCase("RC") && !ski_id.substring(0,2).equalsIgnoreCase("ED")) {
				System.out.print("Enter ski ID (format: RC/ED#####): ");
				ski_id = scan.next(); 							// Input Ski ID
			}
			
			System.out.println();
			
			while (friction_c <= 0) {							// Prevent invalid inputs
				System.out.print("Enter friction coefficient for ski " + ski_id + ": ");
				friction_c = scan.nextDouble(); 					// Input friction coefficient
			}
			
			if (ski_id.substring(0,2).equals("RC")) { 					// Check if model "RC"
				ski_price = RC_MODEL; 							// Set price to model RC
			}else if (ski_id.substring(0,2).equals("ED")) { // Check if model "ED"
				ski_price = ED_MODEL; 							// Set price to model ED
			}
			
			System.out.print("Component cost for ski " + ski_id + ": $" + ski_price); 	// Output component cost
			
			if (friction_c > FRICTION_COEFIFFICIENT) { 				  	// Test if rejected or not
				System.out.print("	<-- REJECT");
				rejected_skis++;
				rejected_cost += ski_price;
			}
			
			System.out.println();
			System.out.println();
			
			average += friction_c; 							 	// Add up friction coefficients to compute average when done
			
			ski_id = "xxxx";							  	// Reset variables for loop
			friction_c = 0;
			
		}
		
		average /= num_data_points; 							  	// Compute average based on number of data points
		
		rejected_percent += rejected_skis; 						  	// Compute percentage of rejected to data points
		rejected_percent /= num_data_points;
		rejected_percent *= 100;
		
													// Output section of data
		System.out.println("Number of Data Points: " + num_data_points);
		System.out.println("Average Friction Coefficient: " + String.format("%.2f",average));
		System.out.println("Number of rejected skis: " + rejected_skis);
		System.out.println("Percentage of rejected skis: " + rejected_percent + "%");
		System.out.println("Cost of rejected skis: $" + String.format("%.2f", rejected_cost));
	}
}
