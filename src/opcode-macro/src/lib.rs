use std::sync::atomic::*;
use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, Item, Ident, Generics};

// Global counter for opcode IDs
static OPCODE_COUNTER: AtomicU32 = AtomicU32::new(0);

#[proc_macro_attribute]
pub fn op(_attr: TokenStream, item: TokenStream) -> TokenStream {
    let input = parse_macro_input!(item as Item);
    
    // Extract the name and generics based on the item type
    let (name, generics) = match &input {
        Item::Struct(item_struct) => (&item_struct.ident, &item_struct.generics),
        Item::Enum(item_enum) => (&item_enum.ident, &item_enum.generics),
        Item::Union(item_union) => (&item_union.ident, &item_union.generics),
        Item::Type(item_type) => (&item_type.ident, &item_type.generics),
        _ => {
            return syn::Error::new_spanned(
                &input,
                "op attribute can only be applied to structs, enums, unions, or type aliases"
            ).to_compile_error().into();
        }
    };
    
    // Get the next available ID
    let id = OPCODE_COUNTER.fetch_add(1, Ordering::SeqCst);

    let repr = if id < 256 {
        quote! { u8 }
    } else if id < 65536 {
        quote! { u16 }
    } else {
        quote! { u32 }
    };
    
    let name_str = name.to_string();
    
    // Split generics for implementation
    let (impl_generics, ty_generics, where_clause) = generics.split_for_impl();
    
    // Generate the Opcode implementation
    let opcode_impl = quote! {
        impl #impl_generics OpCode for #name #ty_generics #where_clause {
            type Repr = #repr;
            const ID: Self::Repr = #id as #repr;
            const NAME: OpName = OpName(#name_str);
        }
    };
    
    // Combine the original item with the new implementation
    let expanded = quote! {
        #input
        #opcode_impl
    };
    
    TokenStream::from(expanded)
}