use itertools::Itertools;
use parse::{Parse, ParseStream};
use proc_macro::{Span, TokenStream};
use quote::{format_ident, quote};
use syn::*;

#[proc_macro]
pub fn params(_input: proc_macro::TokenStream) -> proc_macro::TokenStream {
    let mut output = proc_macro2::TokenStream::new();

    for arity in 0..=8 {
        let impl_block = params_arity(arity);
        output.extend(impl_block);
    }

    output.into()
}

fn params_arity(arity: usize) -> proc_macro2::TokenStream {
    let input_types = (0..arity)
        .map(|i| quote::format_ident!("T{}", i))
        .collect::<Vec<_>>();

    let input_tuple = quote! { (#(#input_types,)*) };

    quote! {
        impl<#(#input_types: Param + 'static),*> Params for #input_tuple {
            fn bind(world: &mut World) -> Metatable {
                let mut archetype = Archetype::default();
                #(#input_types::inject(&mut archetype);)*;
                world.supertype(archetype)
            }
        }
    }
}

#[proc_macro]
pub fn func(_input: TokenStream) -> TokenStream {
    let mut output = proc_macro2::TokenStream::new();

    for arity in 0..=8 {
        let impl_block = func_arity(arity);
        output.extend(impl_block);
    }

    output.into()
}

fn func_arity(arity: usize) -> proc_macro2::TokenStream {
    let input_types = (0..arity)
        .map(|i| quote::format_ident!("T{}", i))
        .collect::<Vec<_>>();
    let input_params = (0..arity)
        .map(|i| quote::format_ident!("t{}", i))
        .collect::<Vec<_>>();

    let input_tuple = quote! { (#(#input_types,)*) };

    let execute_params = quote! { (#(#input_params,)*) };

    quote! {
        impl<F, R: Send, #(#input_types: Send),*> Func<#input_tuple, Blocking<R>> for F
        where
            F: FnOnce(#(#input_types),*) -> R + 'static + Send + Clone,
            R: Outcome
        {
            fn derive(&self) -> Self where Self: Sized {
                self.clone()
            }
            fn execute(self, input: #input_tuple) -> impl Future<Output = R> + Send {
                let #execute_params = input;
                use std::future::ready;
                ready(self(#(#input_params),*))
            }
        }
        impl<F, Fut: Future<Output = R> + Send, R: Send, #(#input_types: Send),*> Func<#input_tuple, Concurrent<Fut>> for F
        where
            F: AsyncFnOnce<(#(#input_types,)*), CallOnceFuture = Fut, Output = R> + 'static + Send + Clone,
        {
            fn derive(&self) -> Self where Self: Sized {
                self.clone()
            }
            fn execute(self, input: #input_tuple) -> impl Future<Output = R> + Send
                where
                    Self: Sized
            {
                self.async_call_once(input)
            }
        }
    }
}
