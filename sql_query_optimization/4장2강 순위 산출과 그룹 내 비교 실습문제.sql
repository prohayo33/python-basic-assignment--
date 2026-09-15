/*
============================================================
[4장 2강] 실습문제: 순위 산출과 그룹 내 비교 함수
============================================================

[실습 목표]
- ROW_NUMBER, RANK, DENSE_RANK의 동점 처리 차이를 설명할 수 있다.
- PARTITION BY를 이용하여 그룹별 순위를 계산할 수 있다.
- 그룹별 상위 N개 데이터를 추출할 수 있다.
- NTILE을 이용하여 데이터를 균등한 그룹으로 나눌 수 있다.
- 순위와 그룹 결과를 비즈니스 지표 관점에서 해석할 수 있다.

[사용 환경]
- PostgreSQL
- DBeaver

[사용 데이터]
이번 과정에서는 아래 12개 CSV로 구성된 동일한 Retail Data Warehouse 데이터셋을 계속 사용합니다.

- customers
- employees
- order_items
- orders
- payments
- products
- promotions
- returns
- shipments
- stores
- suppliers
- categories

[이번 강에서 주로 사용하는 테이블]
- order_items
- products
- orders
- customers

[주요 관계]
- order_items.product_id = products.product_id
- orders.order_id = order_items.order_id
- orders.customer_id = customers.customer_id

[주의사항]
- 현재 데이터셋의 order_items 판매 수량 컬럼은 qty입니다.
- 구매금액은 qty * price로 계산합니다.
- 순위 함수 결과를 WHERE에서 바로 필터링할 수 없으므로
  그룹별 상위 N개를 추출할 때는 서브쿼리 또는 CTE를 사용합니다.
*/



/*
============================================================
필수 1. ROW_NUMBER, RANK, DENSE_RANK 비교
============================================================

[문제 1-1] 상품 판매수량 기준 순위 함수 비교하기

[문제 설명]
전체 상품의 누적 판매수량을 계산한 뒤,
판매수량이 많은 상품부터 순위를 매기려고 합니다.

동일한 판매수량이 발생했을 때
ROW_NUMBER, RANK, DENSE_RANK가 어떻게 다르게 동작하는지 확인하세요.

[요구사항]
1. order_items에서 product_id별 총 판매수량을 계산하세요.
2. 총 판매수량 컬럼명은 total_qty로 지정하세요.
3. 다음 세 순위 함수를 모두 적용하세요.
   - ROW_NUMBER()
   - RANK()
   - DENSE_RANK()
4. 세 함수 모두 total_qty 내림차순을 기준으로 순위를 계산하세요.
5. 결과는 total_qty 내림차순, product_id 오름차순으로 정렬하세요.
6. 동일한 total_qty를 가진 상품이 있는지 확인하세요.
7. 다음 질문에 답하세요.
   Q1. 동점이 있을 때 ROW_NUMBER는 어떻게 처리하나요?
   Q2. RANK와 DENSE_RANK는 동점 다음 순위를 어떻게 다르게 처리하나요?
   Q3. 동점이 전혀 없다면 세 함수 결과는 어떻게 되나요?

[작성 결과]
- 상품별 판매수량 집계 SQL
- 세 순위 함수 비교 SQL
- 동점 여부 확인
- Q1~Q3 답변
*/

-- [코드 작성란]
WITH product_per_total AS  (
SELECT oi.product_id, sum(qty) AS total_qty
FROM order_items oi
GROUP BY oi.product_id )
SELECT product_id, total_qty, ROW_NUMBER() over(ORDER BY total_qty desc) AS row_number_qty, rank() over(ORDER BY total_qty desc)AS rank_qty, DENSE_RANK() over(ORDER BY total_qty desc)AS dense_qty
FROM product_per_total
ORDER BY total_qty DESC, product_id ASC;

-- 동일 판매 수량 존재여부 확인
WITH product_sales AS (
SELECT product_id, sum(qty) AS total_qty
FROM order_items oi 
GROUP BY  product_id)
SELECT total_qty, count(*) AS product_count
FROM product_sales
group BY total_qty
HAVING count(*)>=2
ORDER BY product_count ASC ;



/*
============================================================
필수 2. PARTITION BY로 카테고리별 상위 상품 찾기
============================================================

[문제 2-1] 카테고리별 판매수량 상위 3개 상품 조회

[문제 설명]
상품기획팀에서 전체 상품 순위가 아니라
각 카테고리 안에서 판매량이 높은 상품을 확인하려고 합니다.

상품별 판매수량을 먼저 집계한 뒤,
카테고리별로 순위를 다시 계산하고
각 카테고리의 상위 3개 상품만 조회하세요.

[요구사항]
1. order_items와 products를 product_id 기준으로 JOIN하세요.
2. 다음 기준으로 상품별 총 판매수량을 계산하세요.
   - category_id
   - product_id
3. 총 판매수량 컬럼명은 total_qty로 지정하세요.
4. RANK()를 사용하세요.
5. PARTITION BY category_id를 사용하여
   카테고리마다 순위가 1위부터 다시 시작되도록 하세요.
6. total_qty 내림차순을 기준으로 category_rank를 계산하세요.
7. 계산된 순위가 3 이하인 상품만 조회하세요.
8. 결과를 category_id, category_rank, product_id 순으로 정렬하세요.
9. 다음 질문에 답하세요.
   Q1. PARTITION BY category_id를 사용하면 순위 계산 범위가 어떻게 달라지나요?
   -> 전체 상품을 하나의 순위로 계산하지 않고
   -> 각 category_id별로 별도의 순위 그룹을 만든다.
   -> 왜? 카테고리가 바뀔 때마다 순위가 다시 1부터 시작할 수 있게
   Q2. category_rank <= 3 조건을 같은 SELECT의 WHERE 절에 바로 작성할 수 없는 이유는 무엇인가요?
   -> where절이 실행되는 시점에서 윈도우 함수로 계산된
   -> category_rank가 아직 만들어지기 전이기 때문에
   -> cte나 서브쿼리에서 순위를 계산 한 뒤 바깥 쿼리의 where 에서 필터링한다.
   Q3. RANK를 사용했기 때문에 공동 3위가 여러 상품이면 결과가 3개를 초과할 수 있나요?
   -> 네. rank는 동점에 같은 순위를 부여하기 대문에 공동 3등 상품이 여러개면 모두 category_Rank <= 3 조건을 만족한다.
   

[작성 결과]
- 상품별 판매수량 집계
- 카테고리별 순위 SQL
- 상위 3개 필터링 SQL
- Q1~Q3 답변
*/

-- [코드 작성란]
WITH category_total as(
SELECT category_id, p.product_id, sum(qty) AS total_qty, rank() over(PARTITION BY category_id ORDER BY sum(oi.qty) desc)AS category_rank
FROM order_items oi JOIN products p  ON oi.product_id  =p.product_id 
GROUP BY category_id,p.product_id)
SELECT category_id, product_id, total_qty, category_rank
FROM category_total 
WHERE category_rank <= 3
ORDER BY category_id, category_rank, product_id;



/*
============================================================
과제. NTILE을 이용한 고객 구매등급 분류
============================================================

[문제 3-1] 고객을 구매금액 기준 4개 그룹으로 나누기

[문제 설명]
마케팅팀에서 고객별 총 구매금액을 기준으로
고객을 4개 그룹으로 나누려고 합니다.

구매금액이 높은 고객부터 정렬하고
NTILE(4)를 이용하여 전체 고객 수를 최대한 균등하게 4개 그룹으로 나누세요.

※ 과제는 필수 문제와 동일한 수준입니다.

[요구사항]
1. orders와 order_items를 order_id 기준으로 JOIN하세요.
2. 고객별 총 구매금액을 SUM(qty * price)로 계산하세요.
3. 총 구매금액 컬럼명은 total_amount로 지정하세요.
4. NTILE(4)를 이용하여 구매금액이 높은 고객부터
   customer_group 1~4를 부여하세요.
5. 결과는 customer_group 오름차순,
   total_amount 내림차순으로 정렬하세요.
6. 각 customer_group별 고객 수를 확인하세요.
7. 각 customer_group별 평균 구매금액을 계산하세요.
8. 다음 질문에 답하세요.
   Q1. NTILE(4)는 금액 범위를 정확히 4등분하나요,
       아니면 고객 수를 기준으로 최대한 균등하게 나누나요?
   Q2. customer_group = 1은 어떤 고객군으로 해석할 수 있나요?
   Q3. 이 결과를 마케팅 업무에 어떻게 활용할 수 있나요?

[제출 결과]
- 고객별 총 구매금액 CTE
- NTILE(4) 적용 SQL
- 그룹별 고객 수
- 그룹별 평균 구매금액
- Q1~Q3 답변
*/

-- [코드 작성란]

WITH customer_totals AS ( 
SELECT customer_id, sum(qty * price) AS total_amount
FROM orders o JOIN order_items oi ON oi.order_id = o.order_id 
GROUP BY customer_id
),
ntile_customer_totals AS( 
SELECT customer_id, total_amount, NTILE(4) OVER (ORDER BY total_amount DESC ) AS customer_group 
FROM customer_totals 
ORDER BY customer_group, total_amount  DESC
)
SELECT customer_group, count(*) AS customer_group_value, round(avg(total_amount),2) AS avg_price_amount
FROM ntile_customer_totals
GROUP BY customer_group;

/*
   Q1. NTILE(4)는 금액 범위를 정확히 4등분하나요,
       아니면 고객 수를 기준으로 최대한 균등하게 나누나요?
       -> 고객 수를 기준으로 최대한 균등하게 나눈다.
        
   Q2. customer_group = 1은 어떤 고객군으로 해석할 수 있나요?
   	   -> 평균 구매금액이 높은 고객군이다.
   	    
   Q3. 이 결과를 마케팅 업무에 어떻게 활용할 수 있나요?
   	   -> customer_group = 1인 그룹을 대상으로 VIP 마케팅 캠페인의 타깃으로 정할 수 있다. 


*/

/*
============================================================
실습 마무리
============================================================

아래 내용을 한 문단으로 정리하세요.

1. ROW_NUMBER, RANK, DENSE_RANK의 가장 큰 차이는 무엇인가요?
2. PARTITION BY를 순위 함수와 함께 사용하면 무엇이 달라지나요?
3. 그룹별 상위 N개를 추출할 때 서브쿼리나 CTE가 필요한 이유는 무엇인가요?
4. NTILE 결과를 비즈니스 지표로 해석할 때 주의해야 할 점은 무엇인가요?
*/
