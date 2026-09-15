/*
============================================================
[3장 1강] 실습문제: CTE와 중첩 서브쿼리의 구조적 차이와 최적화 특성
============================================================

[실습 목표]
- 중첩 서브쿼리와 CTE로 같은 로직을 각각 작성할 수 있다.
- CTE를 이용해 복잡한 쿼리를 단계별로 나누어 표현할 수 있다.
- EXPLAIN을 이용해 중첩 서브쿼리와 CTE의 실행계획을 비교할 수 있다.
- MATERIALIZED CTE의 실행계획에서 CTE Scan 여부를 확인할 수 있다.
- 성능뿐 아니라 가독성·재사용성·유지보수성 관점에서 적절한 구조를 판단할 수 있다.

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
- orders
- order_items
- customers

[주요 관계]
- orders.customer_id = customers.customer_id
- orders.order_id = order_items.order_id

[주의사항]
- 현재 데이터셋의 order_items에는 quantity, list_price, discount 컬럼이 없고
  qty, price 컬럼이 있으므로 구매금액은 qty * price로 계산합니다.
- PostgreSQL 버전과 옵티마이저 판단에 따라 일반 CTE는 본문에 인라인될 수 있습니다.
- 특정 실행계획 모양 자체를 외우는 것이 아니라,
  실제 EXPLAIN 결과를 보고 구조를 해석하는 것이 중요합니다.
*/


/*
============================================================
필수 1. 같은 로직을 중첩 서브쿼리와 CTE로 작성하기
============================================================

[문제 1-1] 고객별 총 구매금액이 50,000 이상인 고객 조회

[문제 설명]
고객별 총 구매금액을 계산한 뒤,
총 구매금액이 50,000 이상인 고객만 조회하려고 합니다.

같은 결과를 중첩 서브쿼리와 CTE 두 가지 방식으로 각각 작성하고,
두 쿼리의 구조적 차이를 비교하세요.

[요구사항]
1. orders와 order_items를 order_id 기준으로 JOIN하세요.
2. 고객별 총 구매금액을 다음 식으로 계산하세요.

   SUM(order_items.qty * order_items.price)

3. 고객별 총 구매금액을 계산한 중간 결과에서
   total_amount가 50,000 이상인 고객만 조회하세요.
4. 결과는 total_amount가 높은 순서대로 정렬하세요.
5. 위 로직을 먼저 중첩 서브쿼리 방식으로 작성하세요.
6. 같은 로직을 customer_totals라는 CTE를 이용하여 다시 작성하세요.
7. 두 결과가 동일한지 확인하세요.
8. 중첩 서브쿼리 쿼리에 EXPLAIN을 적용하세요.
9. 일반 CTE 쿼리에 EXPLAIN을 적용하세요.
10. 두 실행계획을 비교하세요.
11. 다음 질문에 답하세요.
   Q1. 중첩 서브쿼리와 CTE의 결과는 달라야 하나요?
   Q2. 여러 단계의 로직을 읽을 때 CTE가 더 이해하기 쉬울 수 있는 이유는 무엇인가요?
   Q3. 이번 문제처럼 중간 결과에 이름을 붙이는 것이 유지보수에 어떤 도움이 되나요?
   Q4. 중첩 서브쿼리와 일반 CTE의 실행계획이 비슷하게 나타난다면,
       어떤 의미로 해석할 수 있나요?

[작성 결과]
- 중첩 서브쿼리 SQL
- CTE SQL
- 두 결과 비교
- 중첩 서브쿼리 EXPLAIN
- 일반 CTE EXPLAIN
- 실행계획 비교
- Q1~Q4 답변
*/

-- [코드 작성란]




/*
============================================================
필수 2. 일반 CTE와 MATERIALIZED CTE 실행계획 비교
============================================================

[문제 2-1] CTE의 구체화 여부 확인하기

[문제 설명]
PostgreSQL에서는 일반 CTE가 항상 별도의 중간 결과로 저장되는 것은 아닙니다.

한 번만 참조되는 일반 CTE는 옵티마이저 판단에 따라
본문 쿼리에 인라인되어 처리될 수 있습니다.

반면 MATERIALIZED를 명시하면
CTE 결과를 먼저 계산한 뒤 그 결과를 읽는 구조를 만들 수 있습니다.

같은 고객별 구매금액 조회를 일반 CTE와 MATERIALIZED CTE로 작성하고,
EXPLAIN을 이용해 실행계획을 비교하세요.

[요구사항]
1. customer_totals CTE에서 고객별 총 구매금액을 계산하세요.
2. total_amount가 50,000 이상인 고객만 조회하세요.
3. 일반 CTE 쿼리에 EXPLAIN을 적용하세요.
4. 같은 CTE에 MATERIALIZED를 명시하고 EXPLAIN을 적용하세요.
5. 두 실행계획에서 다음 내용을 확인하세요.
   - CTE Scan 노드의 존재 여부
   - 고객별 집계 작업이 어느 위치에서 수행되는지
   - 필터 조건이 어느 단계에서 적용되는지
6. 다음 질문에 답하세요.
   Q1. 일반 CTE는 항상 CTE Scan으로 나타나나요?
   Q2. MATERIALIZED를 사용하면 처리 흐름이 어떻게 달라지나요?
   Q3. MATERIALIZED가 항상 더 빠르다고 말할 수 있나요?

[작성 결과]
- 일반 CTE + EXPLAIN
- MATERIALIZED CTE + EXPLAIN
- 실행계획 비교
- Q1~Q3 답변
*/

-- [코드 작성란]




/*
============================================================
과제. 여러 단계 분석을 CTE로 구조화하기
============================================================

[문제 3-1] 우수 고객의 도시별 구매금액 집계

[문제 설명]
운영팀에서 고객별 구매금액을 계산한 뒤,
총 구매금액이 50,000 이상인 우수 고객만 추려
도시별 우수 고객 수와 구매금액을 집계하려고 합니다.

이번 문제에서는 여러 단계의 로직을 CTE로 나누어
쿼리의 흐름을 명확하게 표현하세요.

※ 과제는 필수 문제와 동일한 수준입니다.
   새로운 SQL 문법을 사용하는 것이 아니라,
   이번 강에서 배운 CTE 구조화를 한 번 더 적용하는 문제입니다.

[요구사항]
1. 첫 번째 CTE customer_totals를 작성하세요.
   - orders와 order_items를 order_id 기준으로 JOIN
   - customer_id별 총 구매금액 계산
   - 총 구매금액 컬럼명은 total_amount
2. 두 번째 CTE high_value_customers를 작성하세요.
   - customer_totals에서 total_amount가 50,000 이상인 고객만 선택
3. high_value_customers와 customers를 customer_id 기준으로 JOIN하세요.
4. 도시별로 다음 값을 계산하세요.
   - 우수 고객 수: vip_customer_count
   - 우수 고객 총 구매금액: vip_total_amount
5. vip_total_amount가 높은 순서대로 정렬하세요.
6. 작성한 전체 CTE 쿼리에 EXPLAIN을 적용하여 실행계획을 확인하세요.
7. 실행계획에서 CTE가 본문에 인라인된 형태인지,
   별도의 CTE Scan이 나타나는지 확인하세요.
8. 다음 질문에 답하세요.
   Q1. 이 문제를 하나의 중첩 서브쿼리로 작성하는 것보다 CTE로 나누었을 때 어떤 장점이 있나요?
   Q2. customer_totals와 high_value_customers라는 이름은 각각 어떤 처리 단계를 의미하나요?
   Q3. 성능 차이가 거의 없다면 CTE와 중첩 서브쿼리 중 어떤 기준으로 구조를 선택하는 것이 좋나요?
   Q4. 이번 EXPLAIN 결과를 기준으로 CTE가 실제 실행 단계에서
       반드시 별도의 중간 결과로 저장되었다고 말할 수 있나요?
       실행계획을 근거로 설명하세요.

[제출 결과]
- 전체 CTE SQL
- 도시별 집계 결과
- EXPLAIN 실행계획
- CTE 인라인 또는 CTE Scan 여부 확인
- Q1~Q4 답변
*/

-- [코드 작성란]
-- 1~6
EXPLAIN
WITH customer_totals AS (
SELECT customer_id, sum(qty * price)AS total_amount
FROM orders o JOIN order_items oi ON o.order_id = oi.order_id 
GROUP BY customer_id
),
high_value_customers AS (
SELECT *
FROM customer_totals 
WHERE total_amount >= 50000
)
SELECT city, count(*)AS vip_customer_count, sum(total_amount)AS vip_total_amount
FROM high_value_customers h JOIN customers c ON h.customer_id = c.customer_id 
GROUP BY c.city 
ORDER BY vip_total_amount DESC;

-- 7. 별도의 CTE SCAN 나타나지 않았다. cte가 인라인 처리되었다.

/*
 
   Q1. 이 문제를 하나의 중첩 서브쿼리로 작성하는 것보다 CTE로 나누었을 때 어떤 장점이 있나요?
   	-> 복잡한 쿼리를 처리 단계별로 나누어 작성할 수 있어 가독성과 이해도가 높아진다.
   Q2. customer_totals와 high_value_customers라는 이름은 각각 어떤 처리 단계를 의미하나요?
   	-> customer_totals에서는 고객별 총 구매금액을 계산하고 있고 high_Value_customers에서는 총 구매금액 50,000원 이상인 고객만 필터링하고 있다.
   Q3. 성능 차이가 거의 없다면 CTE와 중첩 서브쿼리 중 어떤 기준으로 구조를 선택하는 것이 좋나요?
   	-> 성능 차이가 거의 없다면 가독성과 유지보수성, 각 처리 단계의 명확성을 기준으로 선택해야 한다.
   Q4. 이번 EXPLAIN 결과를 기준으로 CTE가 실제 실행 단계에서
       반드시 별도의 중간 결과로 저장되었다고 말할 수 있나요?
       실행계획을 근거로 설명하세요.
       -> 이번 실행 결과에서 subquery Scan on customer_totals 같이 반드시 별도의 중간 결과로 저장된다고 볼 수 없다. (옵티마이저가 cte를 쿼리 내부에 통합하여 인라인으로 처리할 수도 있다.)
  
  
  
  */


/*
============================================================
실습 마무리
============================================================

아래 내용을 한 문단으로 정리하세요.

1. CTE와 중첩 서브쿼리의 가장 큰 구조적 차이는 무엇인가요?
2. 일반 CTE와 MATERIALIZED CTE의 처리 방식은 어떻게 다를 수 있나요?
3. 실행계획상 성능 차이가 크지 않다면 어떤 기준으로 쿼리 구조를 선택하는 것이 좋나요?
*/
