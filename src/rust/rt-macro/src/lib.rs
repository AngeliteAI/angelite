use itertools::Itertools;
use parse::{Parse, ParseStream};
use proc_macro::{Span, TokenStream};
use quote::{format_ident, quote};
use syn::*;

#[proc_macro_attribute]
pub fn main(_: TokenStream, input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as ItemFn);

    assert!(input.sig.asyncness.is_some(), "Main must be async");

    let block = input.block;

    let output = quote! {
        fn main() {
            base::run(async move {
                #block
            })
        }
    };

    output.into()
}
