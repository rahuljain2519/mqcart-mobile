import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = 'https://asia-south1-mqcart.cloudfunctions.net/api';
const HEADERS = { 'Content-Type': 'application/json' };

export const options = {
  vus: 1,
  iterations: 1,
};

export default function () {
  /* ----------------------------------
     1️⃣ CREATE SOCIETY
  ---------------------------------- */
  const societyRes = http.post(
    `${BASE_URL}/society/create`,
    JSON.stringify({
      name: 'MQ Cart Load Test Society',
      city: 'Bangalore',
      isActive: true,
      createdAt: new Date().toISOString(),
    }),
    { headers: HEADERS }
  );

  check(societyRes, { 'society created': r => r.status === 200 });
  const societyId = societyRes.json().societyId;

  let sellers = [];
  let shops = [];

  /* ----------------------------------
     2️⃣ CREATE 10 SELLER USERS
  ---------------------------------- */
  for (let i = 1; i <= 10; i++) {
    const sellerRes = http.post(
      `${BASE_URL}/user/create`,
      JSON.stringify({
        name: `Seller ${i}`,
        phone: `90000000${i}`,
        role: 'seller',
        societyId,
        isActive: true,
        createdAt: new Date().toISOString(),
      }),
      { headers: HEADERS }
    );

    check(sellerRes, { 'seller created': r => r.status === 200 });
    const sellerId = sellerRes.json().uid;
    sellers.push(sellerId);

    /* ----------------------------------
       3️⃣ CREATE SHOP FOR SELLER
    ---------------------------------- */
    const shopRes = http.post(
      `${BASE_URL}/shop/create`,
      JSON.stringify({
        sellerId,
        societyId,
        shopName: `Seller ${i} Shop`,
        description: 'Test shop for MQ Cart load testing',
        logoUrl: 'https://picsum.photos/200/200?random=' + i,
        bannerUrl: 'https://picsum.photos/1200/400?random=' + i,
        address: 'Test Address',
        phone: `90000000${i}`,
        plan: 'normal',
        productLimit: 20,
        isActive: true,
        createdAt: new Date().toISOString(),
      }),
      { headers: HEADERS }
    );

    check(shopRes, { 'shop created': r => r.status === 200 });
    shops.push(shopRes.json().shopId);
  }

  /* ----------------------------------
     4️⃣ CREATE 20 PRODUCTS PER SHOP
  ---------------------------------- */
  shops.forEach((shopId, index) => {
    const sellerId = sellers[index];

    for (let p = 1; p <= 20; p++) {
      const seed = index * 20 + p;

      const productRes = http.post(
        `${BASE_URL}/product/create`,
        JSON.stringify({
          shopId,
          sellerId,
          societyId,
          name: `Test Product ${index + 1}-${p}`,
          price: 100 + p,
          quantity: 100,
          category: 'general',
          description: 'Test product for image and load testing',
          images: [
            `https://picsum.photos/600/600?random=${seed}`,
            `https://picsum.photos/600/600?random=${seed + 100}`,
          ],
          coverImage: `https://picsum.photos/600/600?random=${seed}`,
          isActive: true,
          createdAt: new Date().toISOString(),
        }),
        { headers: HEADERS }
      );

      check(productRes, { 'product created': r => r.status === 200 });
    }
  });

  console.log('✅ MQ Cart test data created successfully');
}
