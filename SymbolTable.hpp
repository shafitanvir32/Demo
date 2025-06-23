#ifndef SYMBOLTABLE_HEADER
#define SYMBOLTABLE_HEADER
#include<iostream>
#include<string>
#include "ScopeTable.hpp"
using namespace std;

class SymbolTable
{
    int number_of_buckets;
    ScopeTable* current_scopetable;
    int next_scope_id;         // global counter

public:
    SymbolTable(int buckets, bool verbose = false)
      : number_of_buckets(buckets)
      , current_scopetable(nullptr)
      , next_scope_id(1)
    {
        enter_scope(verbose);
    }


    ~SymbolTable()
    {
        while (current_scopetable) {
            ScopeTable* parent = current_scopetable->parent_scope;
            delete current_scopetable;
            current_scopetable = parent;
        }
    }

    ScopeTable* get_current_scopetable() const
    {
        return current_scopetable;
    }

    void enter_scope(bool verbose = false)
    {
        ScopeTable* new_scopetable = new ScopeTable(number_of_buckets, current_scopetable,next_scope_id++);
        current_scopetable = new_scopetable;
        if(verbose) 
            cout << "\tScopeTable# " << current_scopetable->get_id() << " created" << endl;
    }

    void exit_scope()
    {
        if(current_scopetable->parent_scope == nullptr)
        {
            return;
        }
        ScopeTable* temp = current_scopetable;
        current_scopetable = current_scopetable->parent_scope;
        temp->parent_scope = nullptr;
        delete temp;
    }

    bool insert_into_current_scope(const string& name, const string& type, bool verbose = false)
    {
        bool ret = current_scopetable->insert(name, type, verbose);
        if(!ret && verbose) 
            cout << "'" << name << "' already exists in the current ScopeTable"<< endl;
        return ret;
    }

    bool remove_from_current_scope(const string& name, bool verbose = false)
    {
        bool ret = current_scopetable->remove(name, verbose);
        if(!ret && verbose) 
            cout << "Not found in the current ScopeTable"<< endl;
        return ret;
    }

    SymbolInfo* lookup(const string& name, bool verbose = false)
    {
        ScopeTable* curr = current_scopetable;
        while(curr != nullptr)
        {
            SymbolInfo* existing_entry = curr->lookup(name, verbose);
            if(existing_entry != nullptr)
            {
                return existing_entry;
            }
            curr = curr->parent_scope;
        }
        if(verbose) 
            cout << "'" << name << "' not found in any of the ScopeTables" << endl;
        return nullptr;
    }

    ScopeTable* get_scope_table_of_lookup(const string& name)
    {
        ScopeTable* curr = current_scopetable;
        while(curr != nullptr)
        {
            SymbolInfo* existing_entry = curr->lookup(name);
            if(existing_entry != nullptr)
            {
                return curr;
            }
            curr = curr->parent_scope;
        }
        return nullptr;
    }

    void print_current_scope_table() const
    {
        current_scopetable->print_scope_table(1);
    }

    void print_all_scope_tables() const
    {
        ScopeTable* curr = current_scopetable;
        int i=1;
        while(curr != nullptr)
        {
            curr->print_scope_table(i);
            curr = curr->parent_scope;
            i++;
        }
        cout << endl;
    }
};

#endif 
