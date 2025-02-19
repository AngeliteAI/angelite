use itertools::Itertools;
use parse::{Parse, ParseStream};
use proc_macro::{Span, TokenStream};
use quote::{format_ident, quote};
use syn::*;

#[proc_macro_derive(Component)]
pub fn derive_component(input: TokenStream) -> TokenStream {
    // Parse the input tokens into a syntax tree
    let input = parse_macro_input!(input as DeriveInput);
    let name = &input.ident;

    // Generate the implementation
    let expanded = quote! {
        use ecs::component::*;
        impl Component for #name {
            fn meta() -> Meta {
                Meta {
                    id: Id(std::any::TypeId::of::<Self>()),
                    size: std::mem::size_of::<Self>(),
                }
            }
        }
    };

    // Convert back to token stream and return
    TokenStream::from(expanded)
}

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
            fn bind(registry: &mut Registry) -> Metashard {
                Metashard { tables: array![#({
                    let mut archetype = Archetype::default();
                    #input_types::inject(&mut archetype);
                    registry.metatable(archetype)
                }),*] }
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

#[proc_macro]
pub fn query(_input: TokenStream) -> TokenStream {
    let mut output = proc_macro2::TokenStream::new();

    // Generate implementations for tuples of references up to 8 elements
    for arity in 1..=8 {
        let impl_block = query_arity(arity);
        output.extend(impl_block);
    }

    output.into()
}

fn query_arity(arity: usize) -> proc_macro2::TokenStream {
    let types = (0..arity)
        .map(|i| quote::format_ident!("T{}", i))
        .collect::<Vec<_>>();

    // Generate implementations for both immutable and mutable reference tuples
    quote! {
        impl<'a, #(#types: Sink + 'a),*> Query for (#(#types),*) {
            type Ref = (#(<#types as Sink>::Ref,)*);
            type Mut = (#(<#types as Sink>::Mut,)*);

            fn offsets() -> Array<usize, 256> {
                let mut meta = [#(<#types as Sink>::meta(),)*];
                let mut offset = (0..meta.len()).map(|i| meta.iter().take(i).copied().map(|meta| meta.size).sum::<usize>()).collect::<Array<_, 256>>();
                let mut meta_offset = meta.into_iter().zip(offset).collect::<Array<_, 256>>();
                meta_offset.sort_by_key(|(meta, _)| meta.id);
                meta_offset.into_iter().map(|(_, offset)| offset).collect()
            }

            fn archetype() -> Archetype {
                [#(<#types as Sink>::meta(),)*].into_iter().collect()
            }

             fn deduce(state: &mut State, fetcher: &Fetch<Self>) -> Option<Self::Ref> {
                if state.cursor.finished() {
                    None?
                }

                let shard = fetcher.shard.table_slice();

                let table = state.cursor.table();
                let (_, table) = &shard.unwrap()[table];

                let row = state.cursor.row();

                let mut index = 0;
                Some((#(unsafe {
                    let item = <#types as Sink>::coerce_component_data(table.entity(row), state.offsets[index], state.supertype[index]);
                    index += 1;
                    item
                },)*))
             }

             fn deduce_mut(state: &mut State, fetcher: &mut Fetch<Self>) -> Option<Self::Mut> {
                 if state.cursor.finished() {
                    None?
                }

                let shard = fetcher.shard.table_slice_mut();

                let table = state.cursor.table();
                let (_, table) = &mut shard.unwrap()[table];

                let row = state.cursor.row();

                let mut index = 0;
                Some((#(unsafe {
                    let item = <#types as Sink>::coerce_component_data_mut(table.entity(row), state.offsets[index], state.supertype[index]);
                    index += 1;
                    item
                },)*))
             }
        }
    }
}

#[proc_macro]
pub fn sink(_input: TokenStream) -> TokenStream {
    let mut output = proc_macro2::TokenStream::new();

    for arity in 1..=8 {
        let impl_block = sink_arity(arity);
        output.extend(impl_block);
    }

    output.into()
}

fn sink_arity(arity: usize) -> proc_macro2::TokenStream {
    let input_types = (0..arity)
        .map(|i| quote::format_ident!("T{}", i))
        .collect::<Vec<_>>();
    let input_params = (0..arity)
        .map(|i| quote::format_ident!("t{}", i))
        .collect::<Vec<_>>();

    let input_tuple = quote! { (#(#input_types,)*) };

    quote! {
        impl<#(#input_types: Sink + 'static),*> Sink for #input_tuple {
            unsafe fn erase_component_data<'a>(self) -> Array<(Handle<'a>, Data), 256>  where Self: 'a {
                let (#(#input_params,)*) = self;
                let mut raw_data = array![#(#input_params.erase_component_data(),)*].into_iter().flatten().collect::<Array<_, 256>>();
                raw_data.sort_by_key(|(_, data)| data.meta.id);
                raw_data
            }
            unsafe fn archetype(&self) -> Archetype {
                let (#(#input_params,)*) = self;
                let mut raw_data = array![#(#input_params.archetype(),)*].into_iter().flatten().collect::<Archetype>();
                raw_data
            }
        }
    }
}
#[proc_macro]
pub fn source(_input: TokenStream) -> TokenStream {
    let mut output = proc_macro2::TokenStream::new();

    for arity in 1..=8 {
        let impl_block = source_arity(arity);
        output.extend(impl_block);
    }

    output.into()
}

fn source_arity(arity: usize) -> proc_macro2::TokenStream {
    let input_types = (0..arity)
        .map(|i| quote::format_ident!("T{}", i))
        .collect::<Vec<_>>();
    let input_params = (0..arity)
        .map(|i| quote::format_ident!("t{}", i))
        .collect::<Vec<_>>();

    let input_tuple = quote! { (#(#input_types,)*) };

    quote! {
        impl<#(#input_types: Source + 'static),*> Source for #input_tuple {
            unsafe fn erase_component_data<'a>(self) -> Array<(Handle<'a>, Data), 256>  where Self: 'a {
                let (#(#input_params,)*) = self;
                let mut raw_data = array![#(#input_params.erase_component_data(),)*].into_iter().flatten().collect::<Array<_, 256>>();
                raw_data.sort_by_key(|(_, data)| data.meta.id);
                raw_data
            }
            unsafe fn archetype(&self) -> Archetype {
                let (#(#input_params,)*) = self;
                let mut raw_data = array![#(#input_params.archetype(),)*].into_iter().flatten().collect::<Archetype>();
                raw_data
            }
        }
    }
}

#[proc_macro]
pub fn set(_input: TokenStream) -> TokenStream {
    let mut output = proc_macro2::TokenStream::new();

    for arity in 1..=8 {
        let impl_block = set_arity(arity);
        output.extend(impl_block);
    }

    output.into()
}

fn set_arity(arity: usize) -> proc_macro2::TokenStream {
    let input_types = (0..arity)
        .map(|i| quote::format_ident!("T{}", i))
        .collect::<Vec<_>>();
    let input_params = (0..arity)
        .map(|i| quote::format_ident!("t{}", i))
        .collect::<Vec<_>>();
    let marker_types = (0..arity)
        .map(|i| quote::format_ident!("M{}", i))
        .collect::<Vec<_>>();

    let input_decl = quote! { #(#input_types: Sequence<#marker_types>,)* };

    let input_tuple = quote! { (#(#input_types,)*) };
    let execute_params = quote! { (#(#input_params,)*) };

    quote! {
        impl<#input_decl #(#marker_types: Provider),*> Sequence<Set<(#(#marker_types,)*)>> for #input_tuple {
            type Input = ();
            type Output = ();
            type Return = ();

            fn transform(self, graph: &mut Graph) {
                let #execute_params = self;
                #(#input_params.transform(graph);)*
            }
            fn iter(&self) -> impl Iterator<Item = Id> where Self: Sized {
                let #execute_params = self;
                let iter = iter::empty();
                #(let iter = iter.chain(#input_params.iter());)*
                iter
            }
        }
    }
}
