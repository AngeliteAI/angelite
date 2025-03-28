/** @type {import('./$types').PageLoad} */
export function load({ form }) {
  return {
    hello: form?.message ?? "",
  };
}
