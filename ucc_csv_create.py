#!/usr/bin/python3

import csv

ucc_dictionary_file_list = [
    './downloads/diary08/diary08/uccd08.txt',
    './downloads/diary09/diary09/uccd09.txt',
    './downloads/diary11/diary11/uccd11.txt',
    './downloads/diary10/diary10/uccd10.txt',
]

cleaned_ucc_dictionary = dict()

for dictionary in ucc_dictionary_file_list:
    with open(dictionary) as file:
        line_list = file.read().splitlines()
        for line in line_list:
            ucc_tuple = tuple(line.split(" ", 1))
            cleaned_ucc_dictionary[int(ucc_tuple[0])] = ucc_tuple[1]

with open('cleaned_ucc_dictionary.csv', 'w', newline='') as csvfile:
    ucc_writer = csv.writer(csvfile, delimiter=',', quoting=csv.QUOTE_MINIMAL)
    for key, value in cleaned_ucc_dictionary.items():
        ucc_writer.writerow([key, value])
# print(len(cleaned_ucc_dictionary.keys()))
        # print(line_list)