import java.io.*;
import java.util.Scanner;

public class Driver {
	public static void main(String args[]) throws IOException {
		
		FoxGame game = new FoxGame();								// Create FoxGame object
		Scanner scan = new Scanner(System.in);							// Create scanner for item scanning
		
		String item = "";									// Create string for item
		
		System.out.println("Fox Game by Ethan Esber");
		
		while (!game.lost() && !game.won()) {							// While you haven't lost and you haven't won
			System.out.println();
			System.out.println("Farmer location: " + game.getFarmerBank());
													// Display south bank items
			System.out.println("South bank contains: [" + game.displaySouthBank() + "]");
													// Display north bank items
			System.out.println("North bank contains: [" + game.displayNorthBank() + "]");
			
			while(!game.found(item) && !item.equalsIgnoreCase("none")) {			// While the item is not found and item is not none
				System.out.println();
				System.out.print("Enter the item to transport (fox, chicken, grain, none) : ");
				item = scan.nextLine();							// Input an item
				game.transport(item);							// Transport the item to the other bank
				game.farmerLocation = game.getOtherBank();				// Change farmer's bank to the opposite
			}
			
			item = "";									// Reset item
		} 
		
		System.out.println("Game is over");
		System.out.println();
		System.out.println("Farmer location: " + game.getFarmerBank());
													// Display south bank items
		System.out.println("South bank contains: [" + game.displaySouthBank() + "]");
													// Display north bank items
		System.out.println("North bank contains: [" + game.displayNorthBank() + "]");
		
		if (game.lost())									// If game was lost
			System.out.println("You lost.");
		else if (game.won())									// If game was won
			System.out.println("You won.");
		
		
	}
}
