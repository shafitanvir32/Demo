#ifndef HASH_HEADER
#define HASH_HEADER
#include<iostream>
#include<string>
using namespace std;
class Hash
{
public:
	static unsigned int SDBMHash ( string str , unsigned int num_buckets ) {
 unsigned int hash = 0;
    for (unsigned char c : str) {
        hash = c + (hash << 6) + (hash << 16) - hash;
    }
    return hash%num_buckets;
         }
};
#endif