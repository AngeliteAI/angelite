#![feature(set_ptr_value)]

use itertools::Itertools;
use parse::{Parse, ParseStream};
use proc_macro::{Span, TokenStream};
use quote::{format_ident, quote};
use syn::*;
#[proc_macro_attribute]
pub fn component(attr: TokenStream, input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as Item);

    match input {
        Item::Struct(s) => component_struct(s, attr),
        Item::Trait(t) => component_trait(t, attr),
        _ => panic!("The `component` attribute can only be applied to structs and traits."),
    }
}

fn component_struct(input: ItemStruct, mut attr: TokenStream) -> TokenStream {
    if attr.is_empty() {
        attr = quote! { dyn ecs::component::Component }.into();
    }
    let name = &input.ident;
    let mut attr_args = parse_macro_input!(attr as AttrArgs);
    let set = attr_args.types.remove(0);

    let expanded = quote! {
        #input // Keep the original struct definition

        impl ecs::component::Component for #name {
            fn meta() -> ecs::component::Meta {
                ecs::component::Meta {
                    id: ecs::component::Id(std::any::TypeId::of::<Self>()),
                    size: std::mem::size_of::<Self>(),
                }
            }
        }

        impl ecs::component::source::Source for #name {
            type Table = #set;
            unsafe fn erase_component_data<'a>(mut self) -> ecs::component::table::Components<'a>
            where
                Self: 'a + Sized
            {
                let mut original = Box::new(self);
                use ecs::component::table::Erase;
                let (original, data) = original.erase();
                let original = Box::into_raw(original as Box<Self::Table>);
                let (_, vtable) = original.to_raw_parts();
                let original = Box::from_raw(original);
                let mut arr = vec![];
                arr.push((ecs::component::Handle(original, std::mem::transmute(vtable)), data));
                arr
            }
            unsafe fn archetype(&self) -> ecs::component::archetype::Archetype {
                ecs::component::archetype::Archetype::from_iter([<#name as Component>::meta()])
            }
        }

        impl ecs::component::access::Access for #name {
            fn access<'a>(ptr: *mut u8, vtable: std::ptr::DynMetadata<dyn Component>) -> &'a mut Self {

                unsafe { &mut *(ptr as *mut #name) }
            }

            fn meta() -> Vec<ecs::component::Meta> {
                vec![<#name as ecs::component::Component>::meta()]
            }
        }
    };

    expanded.into()
}

fn component_trait(input: ItemTrait, attr: TokenStream) -> TokenStream {
    let name = &input.ident;
    let attr_args = parse_macro_input!(attr as AttrArgs);

    let meta_variants = attr_args.types.iter().map(|ty| {
        quote! {
            <#ty as ecs::component::Component>::meta()
        }
    });

    let expanded = quote! {
        #input // Keep the original trait definition

        impl ecs::component::access::Access for dyn #name {

            fn access<'a>(ptr: *mut u8, vtable: std::ptr::DynMetadata<dyn Component>) -> &'a mut Self {
                unsafe {
                    (std::ptr::from_raw_parts_mut(ptr, std::mem::transmute(vtable)) as *mut dyn #name).as_mut().unwrap()
                }
            }

            fn meta() -> Vec<ecs::component::Meta> {
                vec![#(#meta_variants,)*]
            }

        }
    };
    expanded.into()
}

struct AttrArgs {
    types: Vec<Type>,
}

impl Parse for AttrArgs {
    fn parse(input: ParseStream) -> Result<Self> {
        let types = syn::punctuated::Punctuated::<Type, Token![,]>::parse_terminated(input)?
            .into_iter()
            .collect();

        Ok(AttrArgs { types })
    }
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
        impl<'a, #(#input_types: Param<'a> + 'static),*> Params<'a> for #input_tuple {

            fn bind(registry: &mut Registry) -> Shard {
                    let mut archetypes = Vec::<Archetype>::default();
                    #(#input_types::inject(&mut archetypes);)*
                        let mut shard = Shard::Linear { tables: vec![].into() };
                    for archetype in archetypes {
                        shard += registry.shard(archetype);
                    }
                    shard
            }
            fn create(archetype: &'a [Archetype], mut table: &'a mut [&'a mut Table]) -> Self where Self: Sized {
                let table = UnsafeCell::new(table);
                (#(#input_types::create(archetype, unsafe { table.get().as_mut().unwrap() }),)*)
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

            fn offsets(index: usize) -> Option<Array<usize, 256>> {
                let mut meta = [#(*<#types as Sink>::meta().get(index)?,)*];
                let mut offset = (0..meta.len()).map(|i| meta.iter().take(i).copied().map(|meta| meta.size).sum::<usize>()).collect::<Array<_, 256>>();
                let mut meta_offset = meta.into_iter().zip(offset).collect::<Array<_, 256>>();
                meta_offset.sort_by_key(|(meta, _)| meta.id);
                Some(meta_offset.into_iter().map(|(_, offset)| offset).collect())
            }

            fn archetype(index: usize) -> Option<Archetype> {
                Some([#(*<#types as Sink>::meta().get(index)?,)*].into_iter().collect())
            }

             fn deduce(state: &mut State, fetcher: &Fetch<Self>) -> Option<Self::Ref> {
                let cursor = state.cursor;
                if state.check(fetcher) {
                    None?
                }

                let row = cursor.row();
                let table = cursor.table();

                let mut index = 0;
                Some((#(unsafe {
                    let item = <#types as Sink>::coerce_component_data(fetcher.tables[table].entity(row)?, state.offsets[index], state.supertype[index], fetcher.tables[table].handle(row, index));
                    index += 1;
                    item
                },)*))
             }

             fn deduce_mut(state: &mut State, fetcher: &mut Fetch<Self>) -> Option<Self::Mut> {
                 if state.check(fetcher) {
                    None?
                }

                let row = state.cursor.row();
                let table = state.cursor.table();

                let mut index = 0;
                Some((#(unsafe {
                    let item = <#types as Sink>::coerce_component_data_mut(fetcher.tables[table].entity(row)?, state.offsets[index], state.supertype[index], fetcher.tables[table].handle(row, index));
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
            unsafe fn erase_component_data<'a>(self) -> Array<(ecs::component::Handle<'a>, Data), 256>  where Self: 'a {
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
            type Table = #input_tuple;
            unsafe fn erase_component_data<'a>(self) -> Vec<(Handle, Data)>  where Self: 'a {
                let (#(#input_params,)*) = self;
                let mut raw_data = vec![#(#input_params.erase_component_data(),)*].into_iter().flatten().collect::<Vec<_>>();
                raw_data.sort_by_key(|(_, data)| data.meta.id);
                raw_data
            }
            unsafe fn archetype(&self) -> Archetype {
                let (#(#input_params,)*) = self;
                let mut raw_data = vec![#(#input_params.archetype(),)*].into_iter().flatten().collect::<Archetype>();
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
