use itertools::Itertools;
use proc_macro::{Span, TokenStream};
use quote::quote;
use syn::*;

#[proc_macro_attribute]
pub fn main(_: TokenStream, input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as ItemFn);

    assert!(input.sig.asyncness.is_some(), "Main must be async");

    let block = input.block;

    let output = quote! {
        fn main() {
            fast::run(async move {
                #block
            })
        }
    };

    output.into()
}

#[proc_macro]
pub fn swizzle(_: TokenStream) -> TokenStream {
    let pattern = |swizzle: [char; 4]| {
        (1..=4).flat_map(move |len| {
            let components = swizzle.iter().enumerate().map(|(i, &c)| (c, i as u32));

            std::iter::repeat_n(components, len)
                .multi_cartesian_product()
                .collect::<Vec<_>>()
        })
    };

    let patterns = (pattern)(['x', 'y', 'z', 'w'])
        .chain((pattern)(['r', 'g', 'b', 'a']))
        .map(|perm| {
            let (chars, indices): (Vec<_>, Vec<_>) = perm.into_iter().unzip();
            let pattern: String = chars.into_iter().collect();
            let name = Ident::new(
                &(pattern[..1].to_uppercase() + &pattern[1..]),
                Span::call_site().into(),
            );
            let len = indices.len();

            quote! {
                pub struct #name;
                impl Pattern for #name {
                    type Indices = [u32; #len];
                    const MASK: Self::Indices = [#(#indices),*];
                }
            }
        });

    quote! {
        #(#patterns)*
    }
    .into()
}
