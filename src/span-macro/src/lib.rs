// Cargo.toml dependencies needed:
// [dependencies]
// proc-macro2 = "1.0"
// quote = "1.0"
// syn = { version = "2.0", features = ["full", "parsing", "printing", "visit-mut"] }
//
// [lib]
// proc-macro = true
use proc_macro::TokenStream;
use proc_macro2::{Span, TokenStream as TokenStream2};
use quote::{quote, ToTokens};
use syn::{
    parse::{Parse, ParseStream},
    parse_macro_input,
    punctuated::Punctuated,
    Attribute, Error, Expr, Fields, Ident, Item, ItemEnum, Lit, LitInt, Meta, MetaList, Path, Result,
    Token, Type, Variant, Visibility,
};

/// Input structure for the bytecode macro
struct BytecodeInput {
    items: Vec<Item>,
}

impl Parse for BytecodeInput {
    fn parse(input: ParseStream) -> Result<Self> {
        // Parse all items directly - no discriminant type parameter needed
        let mut items = Vec::new();
        while !input.is_empty() {
            items.push(input.parse::<Item>()?);
        }

        Ok(BytecodeInput {
            items,
        })
    }
}

/// Main proc macro entry point
#[proc_macro]
pub fn bytecode(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as BytecodeInput);
    
    match process_bytecode(input) {
        Ok(tokens) => tokens.into(),
        Err(err) => err.to_compile_error().into(),
    }
}

/// Process the bytecode input and generate the output
fn process_bytecode(input: BytecodeInput) -> Result<TokenStream2> {
    let mut output_items = Vec::new();
    let mut discriminant_counter = 0u64;

    // Check that no enums have repr attributes or manual discriminants - the macro handles this
    for item in &input.items {
        if let Item::Enum(enum_item) = item {
            if has_repr_attribute(&enum_item.attrs) {
                return Err(Error::new_spanned(
                    &enum_item.ident,
                    "Do not specify #[repr(...)] on enums inside bytecode! macro - it will be added automatically"
                ));
            }
            
            // Check for manual discriminants
            for variant in &enum_item.variants {
                if variant.discriminant.is_some() {
                    return Err(Error::new_spanned(
                        &variant.ident,
                        "Do not specify manual discriminants on enum variants inside bytecode! macro - they will be assigned automatically"
                    ));
                }
            }
        }
    }

    // Count total number of variants across all enums to determine repr type
    let total_variants = count_total_variants(&input.items)?;
    let repr_type = determine_repr_type(total_variants)?;

    for item in input.items {
        match item {
            Item::Enum(mut enum_item) => {
                // Add the repr attribute automatically
                ensure_repr_attribute(&mut enum_item, &repr_type);
                
                // Add common derive traits automatically
                ensure_derive_traits(&mut enum_item);
                
                assign_discriminants(&mut enum_item, &mut discriminant_counter, &repr_type)?;
                output_items.push(enum_item.to_token_stream());
            }
            other => {
                // Pass through non-enum items unchanged
                output_items.push(other.to_token_stream());
            }
        }
    }

    Ok(quote! {
        #(#output_items)*
    })
}

/// Check if an enum has a repr attribute
fn has_repr_attribute(attrs: &[Attribute]) -> bool {
    attrs.iter().any(|attr| attr.path().is_ident("repr"))
}

/// Ensure an enum has the specified repr attribute
fn ensure_repr_attribute(enum_item: &mut ItemEnum, repr_type: &Type) {
    // Add the repr attribute (we've already checked that none exist)
    let repr_attr: Attribute = syn::parse_quote! { #[repr(#repr_type)] };
    enum_item.attrs.push(repr_attr);
}

/// Ensure an enum has common derive traits
fn ensure_derive_traits(enum_item: &mut ItemEnum) {
    // Check if the enum already has a derive attribute
    let has_derive = enum_item.attrs.iter().any(|attr| attr.path().is_ident("derive"));
    
    if !has_derive {
        // Add common derive traits
        let derive_attr: Attribute = syn::parse_quote! { 
            #[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)] 
        };
        enum_item.attrs.push(derive_attr);
    }
}

/// Assign consecutive discriminants to enum variants
fn assign_discriminants(
    enum_item: &mut ItemEnum,
    discriminant_counter: &mut u64,
    _discriminant_type: &Type,
) -> Result<()> {
    for variant in &mut enum_item.variants {
        // All variants will get automatic discriminants since we've already checked
        // that no manual discriminants are specified
        let lit = LitInt::new(&discriminant_counter.to_string(), Span::call_site());
        let discriminant_expr: Expr = syn::parse_quote! { #lit };
        variant.discriminant = Some((Token![=](Span::call_site()), discriminant_expr));
        *discriminant_counter += 1;
    }
    
    Ok(())
}

/// Create a discriminant expression for the given value and type
fn create_discriminant_expr(value: u64, discriminant_type: &Type) -> Result<Expr> {
    let lit = LitInt::new(&value.to_string(), Span::call_site());
    
    // Cast to the appropriate type if needed
    match discriminant_type {
        Type::Path(type_path) if type_path.path.is_ident("u8") => {
            if value > u8::MAX as u64 {
                return Err(Error::new(
                    Span::call_site(),
                    format!("Discriminant value {} exceeds u8::MAX", value),
                ));
            }
            Ok(syn::parse_quote! { #lit })
        }
        Type::Path(type_path) if type_path.path.is_ident("u16") => {
            if value > u16::MAX as u64 {
                return Err(Error::new(
                    Span::call_site(),
                    format!("Discriminant value {} exceeds u16::MAX", value),
                ));
            }
            Ok(syn::parse_quote! { #lit })
        }
        Type::Path(type_path) if type_path.path.is_ident("u32") => {
            if value > u32::MAX as u64 {
                return Err(Error::new(
                    Span::call_site(),
                    format!("Discriminant value {} exceeds u32::MAX", value),
                ));
            }
            Ok(syn::parse_quote! { #lit })
        }
        Type::Path(type_path) if type_path.path.is_ident("u64") => {
            Ok(syn::parse_quote! { #lit })
        }
        _ => {
            // For other types, just use the literal and let the compiler handle it
            Ok(syn::parse_quote! { #lit })
        }
    }
}

/// Count total number of enum variants across all enums
fn count_total_variants(items: &[Item]) -> Result<u64> {
    let mut total = 0u64;
    
    for item in items {
        if let Item::Enum(enum_item) = item {
            // Since we've already validated that no manual discriminants exist,
            // we can simply count the variants sequentially
            total += enum_item.variants.len() as u64;
        }
    }
    
    Ok(total)
}

/// Determine the appropriate repr type based on total variant count
fn determine_repr_type(total_variants: u64) -> Result<Type> {
    if total_variants <= (u8::MAX - 1) as u64 {
        Ok(syn::parse_quote! { u8 })
    } else if total_variants <= (u16::MAX - 1) as u64 {
        Ok(syn::parse_quote! { u16 })
    } else if total_variants <= (u32::MAX - 1) as u64 {
        Ok(syn::parse_quote! { u32 })
    } else {
        Ok(syn::parse_quote! { u64 })
    }
}
