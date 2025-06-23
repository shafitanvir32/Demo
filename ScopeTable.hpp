#ifndef SCOPETABLE_HEADER
#define SCOPETABLE_HEADER

#include <iostream>
#include <string>

#include "Hash.hpp"
#include "SymbolInfo.hpp"

using namespace std;

class ScopeTable
{
    int number_of_buckets;
    int id;                         
    SymbolInfo** hash_table;

public:
    ScopeTable* parent_scope;

 
    ScopeTable(int buckets,
               ScopeTable* parent,
               int unique_id)
      : number_of_buckets(buckets)
      , id(unique_id)
      , parent_scope(parent)
    {
        hash_table = new SymbolInfo*[number_of_buckets]();
    }

    ~ScopeTable()
    {

        for (int i = 0; i < number_of_buckets; ++i)
        {
            SymbolInfo* curr = hash_table[i];
            while (curr)
            {
                SymbolInfo* tmp = curr;
                curr = curr->next;
                tmp->next = nullptr;  
                delete tmp;
            }
        }

        delete[] hash_table;
    }

    int get_id() const { return id; }

    int get_bucket_index(const string& name) const
    {
        unsigned h = Hash::SDBMHash (name,number_of_buckets);
        return int(h % number_of_buckets);
    }

    SymbolInfo* lookup(const string& name, bool verbose = false)
    {
        int idx = get_bucket_index(name);
        SymbolInfo* curr = hash_table[idx];
        int pos = 0;
        while (curr)
        {
            if (curr->get_name() == name)
            {
                if (verbose)
                cout << "'" << name << "' found in ScopeTable# " << id
                << " at position " << idx+1 << ", " << pos+1 << endl;           
                return curr;
            }
            curr = curr->next;
            ++pos;
        }
        return nullptr;
    }

bool insert(const string& name, const string& type, bool verbose = false)
{
    int idx = get_bucket_index(name);
    SymbolInfo* curr = hash_table[idx];
    int chainPos = 0;
    string str= "ScopeTable# 1";
    for (int i = 1; i < this->id; i++) {
        str+= ".1";
    }

    // Check for existence
    while (curr)
    {
        if (curr->get_name() == name)
        {
            cout << "< " << name << " : " << type << " > already exists in " 
                 << str << " at position " << idx << ", " << chainPos << endl<<endl;
            return false;
        }
        curr = curr->next;
        ++chainPos;
    }

    // Insertion
    SymbolInfo* newSym = new SymbolInfo(name, type, nullptr);
    curr = hash_table[idx];
    chainPos = 0;

    if (!curr)
    {
        hash_table[idx] = newSym;
    }
    else
    {
        while (curr->next)
        {
            curr = curr->next;
            ++chainPos;
        }
        curr->next = newSym;
        ++chainPos;
    }

    if (verbose)
    {
        cout << "Inserted in ScopeTable# " << id 
             << " at position " << idx + 1 << ", " << chainPos + 1 << endl;
    }

    return true;
}

    bool remove(const string& name, bool verbose = false)
    {
        SymbolInfo* toDel = lookup(name);
        if (!toDel) return false;

        int idx = get_bucket_index(name);
        SymbolInfo* curr = hash_table[idx];
        SymbolInfo* prev = nullptr;
        int pos = 0;

        // find predecessor
        while (curr && curr != toDel)
        {
            prev = curr;
            curr = curr->next;
            ++pos;
        }

        if (prev)
            prev->next = curr->next;
        else
            hash_table[idx] = curr->next;

        curr->next = nullptr;
        delete curr;
        if (verbose)
        cout << "Deleted '" << name
             << "' from ScopeTable# " << id
             << " at position " << idx+1 << ", " << pos+1 << endl;
    

        return true;
    }

void print_scope_table(int indent) {
    // Print ScopeTable header (no tabs)
    cout << "ScopeTable # 1";
    for (int i = 1; i < this->id; i++) {
        cout << ".1";
    }
    cout << endl;
    for (int i = 0; i < number_of_buckets; i++) {
        SymbolInfo* curr = hash_table[i];
        if (curr == NULL) continue; // Only print non-empty buckets

        cout << i << " --> ";
        while (curr != NULL) {
            cout << "< " << curr->get_name() << " : " << curr->get_type() << " >";
            curr = curr->next;
        }
        cout << endl;
    }
}


    
    
};

#endif // SCOPETABLE_HEADER
