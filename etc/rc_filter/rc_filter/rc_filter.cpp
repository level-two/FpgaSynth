// rc_filter.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include "pch.h"
#include <iostream>

int main(int argc, char* argv[])
{
	FILE *fp_in;
	FILE *fp_out;

	if (argc != 3) {
		std::cout << "Usage: " << argv[0] << " input output\n";
		exit(255);
	}

	fopen_s(&fp_in, argv[1], "r");
	if (fp_in == NULL) {
		std::cout << "No such file: " << argv[1] << "\n";
		exit(255);
	}
	
	fopen_s(&fp_out, argv[2], "w");
	
	/*
	fopen_s(&fp_in, "test.txt", "r");
	fopen_s(&fp_out, "test_out.txt", "w");
	*/

	float vout = 0.0f;

	while (!feof(fp_in)) {
		float vin;
		fscanf_s(fp_in, "%f", &vin);
		vout += (vin - vout) * 0.07f;
		fprintf(fp_out, "%f\n", vout);
	}

	fclose(fp_in);
	fclose(fp_out);

	exit(0);
}

// Run program: Ctrl + F5 or Debug > Start Without Debugging menu
// Debug program: F5 or Debug > Start Debugging menu

// Tips for Getting Started: 
//   1. Use the Solution Explorer window to add/manage files
//   2. Use the Team Explorer window to connect to source control
//   3. Use the Output window to see build output and other messages
//   4. Use the Error List window to view errors
//   5. Go to Project > Add New Item to create new code files, or Project > Add Existing Item to add existing code files to the project
//   6. In the future, to open this project again, go to File > Open > Project and select the .sln file
