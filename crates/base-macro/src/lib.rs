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

struct VectorConstants {
    vec_type: Type,
    repr_type: Type,
    zero: Expr,
    one: Expr,
}

impl Parse for VectorConstants {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        let vec_type = input.parse()?;
        let _: Token![,] = input.parse()?;
        let repr_type = input.parse()?;
        let _: Token![,] = input.parse()?;
        let zero = input.parse()?;
        let _: Token![,] = input.parse()?;
        let one = input.parse()?;

        Ok(VectorConstants {
            vec_type,
            repr_type,
            zero,
            one,
        })
    }
}

#[proc_macro]
pub fn vector_constants(input: TokenStream) -> TokenStream {
    let VectorConstants {
        vec_type,
        repr_type,
        zero,
        one,
    } = parse_macro_input!(input as VectorConstants);

    let axes2d = ["X", "Y"];
    let axes3d = ["X", "Y", "Z"];
    let axes4d = ["X", "Y", "Z", "W"];

    let gen_vector = |dim: usize, axes: &[&str]| {
        let axis_constants = axes.iter().enumerate().map(|(idx, axis)| {
            let axis_ident = format_ident!("{}", axis);
            quote! {
                pub const #axis_ident: Self = {
                    let mut arr = [#zero; #dim];
                    arr[#idx] = #one;
                    Self(Simd(arr))
                };
            }
        });

        quote! {
            impl #vec_type<#dim, #repr_type> {
                #(#axis_constants)*

                pub const ZERO: Self = Self(Simd([#zero; #dim]));
                pub const ONE: Self = Self(Simd([#one; #dim]));
            }
        }
    };

    let vec2 = gen_vector(2, &axes2d);
    let vec3 = gen_vector(3, &axes3d);
    let vec4 = gen_vector(4, &axes4d);

    let expanded = quote! {
        #vec2
        #vec3
        #vec4
    };

    expanded.into()
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
